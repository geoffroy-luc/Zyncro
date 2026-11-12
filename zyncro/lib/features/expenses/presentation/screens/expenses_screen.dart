import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:zyncro/features/expenses/presentation/screens/expense_form_screen.dart';
import 'package:zyncro/features/expenses/presentation/widgets/depenses_tab.dart';
import 'package:zyncro/features/expenses/presentation/widgets/equilibre_tab.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTab = 0;
  String _search = '';

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
    final allExpenses = ref.watch(expensesProvider).asData?.value ?? [];
    final expenses = _search.isEmpty
        ? allExpenses
        : allExpenses.where((e) {
            final q = _search.toLowerCase();
            return e.title.toLowerCase().contains(q) ||
                (e.category?.toLowerCase().contains(q) ?? false) ||
                e.paidByName.toLowerCase().contains(q);
          }).toList();
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
      backgroundColor: context.colors.background,
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              heroTag: 'fab_expenses',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ExpenseFormScreen(),
                ),
              ),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.85),
              shape: const CircleBorder(
                side: BorderSide(color: Colors.white24, width: 2),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // ── Tab bar ──────────────────────────────────────────────
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorWeight: 3,
                dividerColor: context.colors.border,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: context.colors.textSecondary,
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

            // ── Search bar ──────────────────────────────────────────
            if (_currentTab == 0)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Icon(
                          Icons.search,
                          color: context.colors.textSecondary,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          decoration: InputDecoration(
                            hintText: context.l10n.expensesRechercherUneDepense,
                            hintStyle: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            filled: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Tabs ─────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Tab 0 : Dépenses ─────────────────────────────
                  DepensesTab(
                    expenses: expenses,
                    total: total,
                    myShare: myShare,
                    currentUid: currentUid,
                  ),
                  // ── Tab 1 : Équilibre ────────────────────────────
                  EquilibreTab(
                    myBalance: myBalance,
                    balances: balances,
                    nameByUid: nameByUid,
                    currentUid: currentUid,
                    members: members,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
