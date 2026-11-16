import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/expenses/domain/services/spending.dart';
import 'package:zyncro/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:zyncro/features/expenses/presentation/screens/expense_form_screen.dart';
import 'package:zyncro/features/expenses/presentation/widgets/depenses_tab.dart';
import 'package:zyncro/features/expenses/presentation/widgets/equilibre_tab.dart';
import 'package:zyncro/features/expenses/presentation/widgets/expense_search_field.dart';

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
  // BUG E21 corrigé : le champ affiche toujours le filtre actif (il
  // revenait vide après un changement d'onglet alors que la liste restait
  // filtrée).
  final _searchController = TextEditingController();

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
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider);
    final allExpenses = expensesAsync.asData?.value ?? [];
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
    // Aperçu du groupe : toujours sur toutes les dépenses (la recherche ne
    // filtre que la liste).
    final (:total, :myShare) = spendingOf(allExpenses, currentUid);

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

            // ── Tabs ─────────────────────────────────────────────────
            Expanded(
              // BUG E16 corrigé : chargement et erreur visibles (au lieu de
              // « 0,00 € » / « Aucune dépense »).
              child: !expensesAsync.hasValue && expensesAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : !expensesAsync.hasValue && expensesAsync.hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          context.l10n.expensesErreurChargement,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      // Bords francs (aussi sur iOS) : arrivé au bord, le
                      // balayage passe aux onglets de l'app (SwipeableBranches).
                      physics: const PageScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      children: [
                        // ── Tab 0 : Dépenses ─────────────────────────────
                        DepensesTab(
                          expenses: expenses,
                          hasAnyExpense: allExpenses.isNotEmpty,
                          searching: _search.isNotEmpty,
                          total: total,
                          myShare: myShare,
                          currentUid: currentUid,
                          search: ExpenseSearchField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _search = v),
                          ),
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
