import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zyncro/core/utils/firestore_stream_extensions.dart';
import 'package:zyncro/features/expenses/data/mappers/expense_mapper.dart';
import 'package:zyncro/features/expenses/domain/entities/expense.dart';
import 'package:zyncro/features/expenses/domain/repositories/expenses_repository.dart';
import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';

class FirestoreExpensesRepository implements ExpensesRepository {
  FirestoreExpensesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String groupId) =>
      _db.collection('groups').doc(groupId).collection('expenses');

  @override
  Stream<List<Expense>> watchExpenses(String groupId) {
    return _col(groupId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) => mapDocsSafely(
            snap.docs,
            ExpenseMapper.fromFirestore,
            label: 'watchExpenses',
          ),
        )
        .surfacePermissionDenied('watchExpenses');
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
    await ref.set(ExpenseMapper.toFirestore(expense));
    return expense;
  }

  @override
  Future<void> updateExpense(String groupId, Expense expense) async {
    await _col(
      groupId,
    ).doc(expense.firestoreId).update(ExpenseMapper.toFirestore(expense));
  }

  @override
  Future<void> deleteExpense(String groupId, String expenseId) async {
    await _col(groupId).doc(expenseId).delete();
  }
}
