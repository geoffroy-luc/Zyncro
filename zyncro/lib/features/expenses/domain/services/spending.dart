import 'package:zyncro/features/expenses/domain/entities/expense.dart';

/// Dépenses du groupe (total) et part d'un membre.
///
/// BUG E23 / G12 corrigés : un remboursement n'est pas une dépense. Il
/// n'entre ni dans le total ni dans « Votre part » (recevoir un
/// remboursement augmentait la part de celui qui le reçoit). Les dépenses
/// soldées restent comptées : elles ont bien été dépensées.
({double total, double myShare}) spendingOf(
  Iterable<Expense> expenses,
  String? uid,
) {
  var total = 0.0;
  var myShare = 0.0;
  for (final e in expenses) {
    if (e.expenseType == ExpenseType.reimbursement) continue;
    total += e.amount;
    if (uid != null) myShare += e.effectiveSplitAmounts[uid] ?? 0.0;
  }
  return (total: total, myShare: myShare);
}
