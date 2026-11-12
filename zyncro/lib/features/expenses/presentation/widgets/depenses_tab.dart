import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/expenses/domain/entities/expense.dart';
import 'package:zyncro/features/expenses/presentation/screens/expense_form_screen.dart';
import 'package:zyncro/features/expenses/presentation/widgets/expense_card.dart';
import 'package:zyncro/features/expenses/presentation/widgets/expenses_overview_row.dart';
import 'package:zyncro/features/expenses/presentation/widgets/expenses_screen_helpers.dart';
import 'package:zyncro/features/expenses/presentation/widgets/expenses_section_card.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';

// ── Tab Dépenses ─────────────────────────────────────────────────────────────

class DepensesTab extends ConsumerWidget {
  final List<Expense> expenses;
  final double total;
  final double myShare;
  final String? currentUid;

  const DepensesTab({
    super.key,
    required this.expenses,
    required this.total,
    required this.myShare,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency =
        ref.watch(tabSettingsProvider).asData?.value.expensesCurrency ?? 'EUR';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aperçu du groupe
          ExpensesSectionCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.expensesApercuDuGroupe,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: context.colors.border),
                  const SizedBox(height: 16),
                  ExpensesOverviewRow(
                    label: context.l10n.expensesTotalDepenses,
                    value: expensesFormatAmount(total, currency: currency),
                    bold: true,
                  ),
                  const SizedBox(height: 12),
                  ExpensesOverviewRow(
                    label: context.l10n.expensesVotrePart,
                    value: expensesFormatAmount(myShare, currency: currency),
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
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: context.colors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.expensesAucuneDepense,
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ExpenseFormScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n.expensesAjouter),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              context.l10n.expensesDepensesRecentes,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            ...expenses.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ExpenseCard(expense: e, isMe: e.paidBy == currentUid),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
