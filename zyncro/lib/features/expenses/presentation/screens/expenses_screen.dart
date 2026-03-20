import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/expense.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/expenses_provider.dart';
import 'expense_form_screen.dart';
import 'reimbursement_form_screen.dart';

const _categoryColors = {
  'Alimentation': Color(0xFF2BB8A5),
  'Logement': Color(0xFF4F7CFF),
  'Transport': Color(0xFF9B59B6),
  'Loisirs': Color(0xFFE85D75),
  'Services': Color(0xFFFFB86B),
  'Autre': Color(0xFF6B7280),
};

Color _catColor(String? cat) => _categoryColors[cat] ?? const Color(0xFF6B7280);

String _formatAmount(double v) {
  final abs = v.abs();
  if (abs >= 1000000) {
    final m = v / 1000000;
    return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1).replaceAll('.', ',')}M €';
  }
  if (abs >= 1000) {
    final k = v / 1000;
    return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1).replaceAll('.', ',')}k €';
  }
  return NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  ).format(v);
}

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays == 0) return "Aujourd'hui";
  if (diff.inDays == 1) return 'Hier';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
  return DateFormat('d MMM', 'fr_FR').format(dt);
}

typedef _Settlement = ({String fromUid, String toUid, double amount});

List<_Settlement> _computeSettlements(Map<String, double> balances) {
  final creditors =
      balances.entries
          .where((e) => e.value > 0.01)
          .map((e) => MapEntry(e.key, e.value))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
  final debtors =
      balances.entries
          .where((e) => e.value < -0.01)
          .map((e) => MapEntry(e.key, e.value))
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));

  final result = <_Settlement>[];
  int ci = 0, di = 0;
  while (ci < creditors.length && di < debtors.length) {
    final credit = creditors[ci].value;
    final debt = debtors[di].value.abs();
    final transfer = min(credit, debt);
    result.add((
      fromUid: debtors[di].key,
      toUid: creditors[ci].key,
      amount: transfer,
    ));
    creditors[ci] = MapEntry(creditors[ci].key, credit - transfer);
    debtors[di] = MapEntry(debtors[di].key, debtors[di].value + transfer);
    if (creditors[ci].value < 0.01) ci++;
    if (debtors[di].value > -0.01) di++;
  }
  return result;
}

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (_tabController.index != _currentTab) {
          setState(() => _currentTab = _tabController.index);
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider).asData?.value ?? [];
    final balances = ref.watch(balancesProvider);
    final currentUid = ref.watch(authStateProvider).asData?.value?.uid;
    final members = ref.watch(expenseMembersProvider).asData?.value ?? [];
    final nameByUid = {for (final m in members) m.uid: m.displayName};

    final myBalance = currentUid != null ? (balances[currentUid] ?? 0.0) : 0.0;
    final total = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final myShare = currentUid == null
        ? 0.0
        : expenses.fold(
            0.0,
            (sum, e) => sum + (e.effectiveSplitAmounts[currentUid] ?? 0.0),
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              heroTag: 'fab_expenses',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
              ),
              backgroundColor: const Color(0xFFFFB86B).withValues(alpha: 0.85),
              shape: const CircleBorder(
                side: BorderSide(color: Colors.white24, width: 2),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          // ── Tab bar ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFFB86B),
              indicatorWeight: 3,
              dividerColor: AppColors.border,
              labelColor: const Color(0xFFFFB86B),
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Dépenses'),
                Tab(text: 'Équilibre'),
              ],
            ),
          ),

          // ── Tabs ─────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 0 : Dépenses ─────────────────────────────
                _DepensesTab(
                  expenses: expenses,
                  total: total,
                  myShare: myShare,
                  currentUid: currentUid,
                ),
                // ── Tab 1 : Équilibre ────────────────────────────
                _EquilibreTab(
                  myBalance: myBalance,
                  balances: balances,
                  nameByUid: nameByUid,
                  currentUid: currentUid,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab Dépenses ─────────────────────────────────────────────────────────────

class _DepensesTab extends ConsumerWidget {
  final List<Expense> expenses;
  final double total;
  final double myShare;
  final String? currentUid;

  const _DepensesTab({
    required this.expenses,
    required this.total,
    required this.myShare,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aperçu du groupe
          _SectionCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aperçu du groupe',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),
                  _OverviewRow(
                    label: 'Total dépenses',
                    value: _formatAmount(total),
                    bold: true,
                  ),
                  const SizedBox(height: 12),
                  _OverviewRow(
                    label: 'Votre part',
                    value: _formatAmount(myShare),
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (expenses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Aucune dépense',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ExpenseFormScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            const Text(
              'Dépenses récentes',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            ...expenses.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExpenseCard(expense: e, isMe: e.paidBy == currentUid),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab Équilibre ─────────────────────────────────────────────────────────────

class _EquilibreTab extends StatelessWidget {
  final double myBalance;
  final Map<String, double> balances;
  final Map<String, String> nameByUid;
  final String? currentUid;

  const _EquilibreTab({
    required this.myBalance,
    required this.balances,
    required this.nameByUid,
    required this.currentUid,
  });

  String _name(String uid) {
    if (uid == currentUid) return 'Vous';
    return nameByUid[uid] ?? uid.substring(0, min(6, uid.length));
  }

  @override
  Widget build(BuildContext context) {
    final settlements = _computeSettlements(balances);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carte mon solde
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: myBalance >= 0
                    ? const [Color(0xFF2BB8A5), Color(0xFF1E9B8A)]
                    : const [Color(0xFFFF6B6B), Color(0xFFE85D75)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color:
                      (myBalance >= 0
                              ? const Color(0xFF2BB8A5)
                              : const Color(0xFFFF6B6B))
                          .withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Votre solde',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  myBalance >= 0
                      ? '+${_formatAmount(myBalance)}'
                      : _formatAmount(myBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      myBalance >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      myBalance >= 0
                          ? 'On vous doit de l\'argent'
                          : 'Vous devez de l\'argent',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Soldes par membre
          if (balances.isNotEmpty) ...[
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text(
                      'Soldes',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: balances.entries.map((entry) {
                        final isPos = entry.value >= 0;
                        final name = _name(entry.key);
                        final initials = name.length >= 2
                            ? name.substring(0, 2).toUpperCase()
                            : name.toUpperCase();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isPos
                                        ? const [
                                            Color(0xFF2BB8A5),
                                            Color(0xFF1E9B8A),
                                          ]
                                        : const [
                                            Color(0xFF6B7280),
                                            Color(0xFF4B5563),
                                          ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    isPos
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 16,
                                    color: isPos
                                        ? const Color(0xFF2BB8A5)
                                        : const Color(0xFFFF6B6B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatAmount(entry.value.abs()),
                                    style: TextStyle(
                                      color: isPos
                                          ? const Color(0xFF2BB8A5)
                                          : const Color(0xFFFF6B6B),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Suggestions de remboursement
          if (settlements.isNotEmpty) ...[
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text(
                      'À régler',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: settlements.map((s) {
                        final fromName = _name(s.fromUid);
                        final toName = _name(s.toUid);
                        final isMe = s.fromUid == currentUid;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: fromName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const TextSpan(text: ' doit '),
                                          TextSpan(
                                            text: _formatAmount(s.amount),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFFF6B6B),
                                            ),
                                          ),
                                          const TextSpan(text: ' à '),
                                          TextSpan(
                                            text: toName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ReimbursementFormScreen(
                                        initialToUid: s.toUid,
                                        initialAmount: s.amount,
                                      ),
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF4F7CFF),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(
                                        color: Color(0xFF4F7CFF),
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Rembourser',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (balances.isNotEmpty) ...[
            _SectionCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2BB8A5).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 18,
                        color: Color(0xFF2BB8A5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Les comptes sont équilibrés',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Widgets helpers ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _OverviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _OverviewRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            fontSize: bold ? 17 : 14,
          ),
        ),
      ],
    );
  }
}

class _ExpenseCard extends ConsumerWidget {
  final Expense expense;
  final bool isMe;

  const _ExpenseCard({required this.expense, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = expense.expenseType == ExpenseType.reimbursement
        ? const Color(0xFF27AE60)
        : _catColor(expense.category);

    final cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (expense.expenseType ==
                                ExpenseType.reimbursement) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4F7CFF,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: const Text(
                                  'Remboursement',
                                  style: TextStyle(
                                    color: Color(0xFF27AE60),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Payé par ${isMe ? 'vous' : expense.paidByName}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const Text(
                                  ' • ',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDate(expense.date),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatAmount(expense.amount),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  if (expense.category != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        expense.category!,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExpenseFormScreen(expense: expense),
        ),
      ),
      child: cardContent,
    );
  }
}
