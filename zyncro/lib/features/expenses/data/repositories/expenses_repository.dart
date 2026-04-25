import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/i_expenses_repository.dart';
import '../../../../shared/models/expense.dart';
import '../../../../shared/models/recurrence_rule.dart';

class ExpensesRepository implements IExpensesRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String groupId) =>
      _db.collection('groups').doc(groupId).collection('expenses');

  @override
  Stream<List<Expense>> watchExpenses(String groupId) {
    return _col(groupId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Expense.fromMap(doc.id, doc.data()))
              .toList(),
        )
        .handleError(
          (_) {},
          test: (e) => e is FirebaseException && e.code == 'permission-denied',
        );
  }

  @override
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
    RecurrenceRule? recurrence,
  }) async {
    final ref = _col(groupId).doc();
    final expense = Expense(
      id: ref.id,
      groupId: groupId,
      title: title,
      amount: amount,
      paidBy: paidBy,
      paidByName: paidByName,
      splitWith: splitWith,
      settled: false,
      category: category,
      date: date,
      createdBy: userId,
      createdAt: DateTime.now(),
      expenseType: expenseType,
      splitType: splitType,
      splitAmounts: splitAmounts,
      recurrence: recurrence,
    );
    await ref.set(expense.toMap());
    return expense;
  }

  @override
  Future<void> updateExpense(String groupId, Expense expense) async {
    await _col(groupId).doc(expense.id).update(expense.toMap());
  }

  @override
  Future<void> deleteExpense(String groupId, String expenseId) async {
    await _col(groupId).doc(expenseId).delete();
  }

  @override
  Future<void> settleExpense(String groupId, String expenseId) async {
    await _col(groupId).doc(expenseId).update({'settled': true});
  }
}
