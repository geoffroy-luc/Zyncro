import 'package:cloud_firestore/cloud_firestore.dart';

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
    );
  }

  double get sharePerPerson =>
      splitWith.isEmpty ? amount : amount / splitWith.length;
}
