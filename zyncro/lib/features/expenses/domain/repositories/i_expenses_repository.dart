import '../../../../shared/models/expense.dart';

abstract interface class IExpensesRepository {
  Stream<List<Expense>> watchExpenses(String groupId);
  Future<Expense> createExpense({
    required String groupId,
    required String title,
    required double amount,
    required String paidBy,
    required String paidByName,
    required List<String> splitWith,
    required ExpenseType expenseType,
    required SplitType splitType,
    Map<String, double>? splitAmounts,
    String? category,
    required DateTime date,
    required String userId,
  });
  Future<void> updateExpense(String groupId, Expense expense);
  Future<void> deleteExpense(String groupId, String expenseId);
  Future<void> settleExpense(String groupId, String expenseId);
}
