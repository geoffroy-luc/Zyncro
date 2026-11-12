import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';

enum ExpenseType { expense, reimbursement }

enum SplitType { equal, amount, percentage }

class Expense {
  final String id;
  // For recurring instances only: the actual Firestore document ID (base.id).
  // Use firestoreId for all Firestore operations.
  final String? baseExpenseId;
  final String groupId;
  final String title;
  final double amount;
  final String paidBy;
  final String paidByName;
  final List<String> splitWith;
  final bool settled;
  final String? category;
  final DateTime date;
  final String createdBy;
  final DateTime createdAt;
  final ExpenseType expenseType;
  final SplitType splitType;
  final Map<String, double>? splitAmounts;
  final String? updatedBy;
  final RecurrenceRule? recurrence;

  String get firestoreId => baseExpenseId ?? id;

  const Expense({
    required this.id,
    this.baseExpenseId,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.paidByName,
    required this.splitWith,
    required this.settled,
    this.category,
    required this.date,
    required this.createdBy,
    required this.createdAt,
    this.expenseType = ExpenseType.expense,
    this.splitType = SplitType.equal,
    this.splitAmounts,
    this.updatedBy,
    this.recurrence,
  });

  Expense copyWith({
    String? title,
    double? amount,
    String? paidBy,
    String? paidByName,
    List<String>? splitWith,
    bool? settled,
    String? category,
    DateTime? date,
    ExpenseType? expenseType,
    SplitType? splitType,
    Map<String, double>? splitAmounts,
    String? updatedBy,
    RecurrenceRule? recurrence,
    bool clearRecurrence = false,
  }) {
    return Expense(
      id: id,
      baseExpenseId: baseExpenseId,
      groupId: groupId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      paidByName: paidByName ?? this.paidByName,
      splitWith: splitWith ?? this.splitWith,
      settled: settled ?? this.settled,
      category: category ?? this.category,
      date: date ?? this.date,
      createdBy: createdBy,
      createdAt: createdAt,
      expenseType: expenseType ?? this.expenseType,
      splitType: splitType ?? this.splitType,
      splitAmounts: splitAmounts ?? this.splitAmounts,
      updatedBy: updatedBy ?? this.updatedBy,
      recurrence: clearRecurrence ? null : recurrence ?? this.recurrence,
    );
  }

  Map<String, double> get effectiveSplitAmounts {
    if (splitAmounts != null && splitAmounts!.isNotEmpty) return splitAmounts!;
    if (splitWith.isEmpty) return {};
    final share = amount / splitWith.length;
    return {for (final uid in splitWith) uid: share};
  }
}
