import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/expenses/domain/entities/expense.dart';
import 'package:zyncro/features/expenses/domain/services/spending.dart';

Expense _e(
  double amount,
  Map<String, double> split, {
  ExpenseType type = ExpenseType.expense,
  bool settled = false,
}) => Expense(
  id: '$amount$type',
  groupId: 'g',
  title: 't',
  amount: amount,
  paidBy: 'a',
  paidByName: 'a',
  splitWith: split.keys.toList(),
  splitAmounts: split,
  settled: settled,
  date: DateTime(2026),
  createdBy: 'a',
  createdAt: DateTime(2026),
  expenseType: type,
);

void main() {
  test('BUG E23 corrigé : un remboursement n’est ni dépense ni part', () {
    final r = spendingOf([
      _e(30, {'a': 15, 'b': 15}),
      _e(15, {'a': 15}, type: ExpenseType.reimbursement),
      _e(10, {'b': 10}, settled: true),
    ], 'a');
    expect(r.total, 40);
    expect(r.myShare, 15);
  });
}
