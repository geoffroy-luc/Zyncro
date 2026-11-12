import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/design_system/tokens/brand_palette.dart';
import 'package:zyncro/features/expenses/domain/entities/expense.dart';
import 'package:zyncro/features/expenses/presentation/screens/expense_form_screen.dart';
import 'package:zyncro/features/expenses/presentation/widgets/expenses_screen_helpers.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';
import 'package:zyncro/shared/domain/categories/expense_category.dart';

class ExpenseCard extends ConsumerWidget {
  final Expense expense;
  final bool isMe;

  const ExpenseCard({super.key, required this.expense, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency =
        ref.watch(tabSettingsProvider).asData?.value.expensesCurrency ?? 'EUR';
    final categories =
        ref.watch(tabSettingsProvider).asData?.value.expensesCategories ??
        defaultExpenseCategories;
    final color = expense.expenseType == ExpenseType.reimbursement
        ? context.colors.success
        : expensesCatColor(categories, expense.category);

    final cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
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
                              style: TextStyle(
                                color: context.colors.textPrimary,
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
                                  // BUG E25 corrigé : fond et texte de la même
                                  // couleur (fond bleu, texte vert avant).
                                  color: BalancePalette.settleAction.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  context.l10n.expensesRemboursement,
                                  style: const TextStyle(
                                    color: BalancePalette.settleAction,
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
                                  isMe
                                      ? context.l10n.expensesPaidByYou
                                      : context.l10n.expensesPaidBy(
                                          expense.paidByName,
                                        ),
                                  style: TextStyle(
                                    color: context.colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  ' • ',
                                  style: TextStyle(
                                    color: context.colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  expensesFormatDate(expense.date),
                                  style: TextStyle(
                                    color: context.colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        expensesFormatAmount(
                          expense.amount,
                          currency: currency,
                        ),
                        style: TextStyle(
                          color: context.colors.textPrimary,
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
        MaterialPageRoute<void>(
          builder: (_) => ExpenseFormScreen(expense: expense),
        ),
      ),
      child: cardContent,
    );
  }
}
