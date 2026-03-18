import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseType { expense, reimbursement }

enum SplitType { equal, amount, percentage }

class Expense {
  final String id;
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

  const Expense({
    required this.id,
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
  });

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      groupId: map['groupId'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      paidBy: map['paidBy'] as String,
      paidByName: map['paidByName'] as String? ?? map['paidBy'] as String,
      splitWith: List<String>.from(map['splitWith'] ?? []),
      settled: map['settled'] as bool? ?? false,
      category: map['category'] as String?,
      date: (map['date'] as Timestamp).toDate(),
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      expenseType: ExpenseType.values.byName(
        map['expenseType'] as String? ?? ExpenseType.expense.name,
      ),
      splitType: SplitType.values.byName(
        map['splitType'] as String? ?? SplitType.equal.name,
      ),
      splitAmounts: map['splitAmounts'] == null
          ? null
          : Map<String, double>.from(
              (map['splitAmounts'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, (v as num).toDouble()),
              ),
            ),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'paidBy': paidBy,
      'paidByName': paidByName,
      'splitWith': splitWith,
      'settled': settled,
      'category': category,
      'date': Timestamp.fromDate(date),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'expenseType': expenseType.name,
      'splitType': splitType.name,
      if (splitAmounts != null) 'splitAmounts': splitAmounts,
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

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
  }) {
    return Expense(
      id: id,
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
    );
  }

  double get sharePerPerson =>
      splitWith.isEmpty ? amount : amount / splitWith.length;

  Map<String, double> get effectiveSplitAmounts {
    if (splitAmounts != null && splitAmounts!.isNotEmpty) return splitAmounts!;
    if (splitWith.isEmpty) return {};
    final share = amount / splitWith.length;
    return {for (final uid in splitWith) uid: share};
  }
}
