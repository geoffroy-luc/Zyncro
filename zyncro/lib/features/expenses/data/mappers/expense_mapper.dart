import 'package:zyncro/features/expenses/domain/entities/expense.dart';
import 'package:zyncro/shared/data/mappers/firestore_codec.dart';
import 'package:zyncro/shared/data/mappers/recurrence_rule_mapper.dart';

/// Champs Firestore d'une dépense (`groups/{gid}/expenses/{id}`).
abstract final class ExpenseFields {
  static const groupId = 'groupId';
  static const title = 'title';
  static const amount = 'amount';
  static const paidBy = 'paidBy';
  static const paidByName = 'paidByName';
  static const splitWith = 'splitWith';
  static const settled = 'settled';
  static const category = 'category';
  static const date = 'date';
  static const createdBy = 'createdBy';
  static const createdAt = 'createdAt';
  static const expenseType = 'expenseType';
  static const splitType = 'splitType';
  static const splitAmounts = 'splitAmounts';
  static const updatedBy = 'updatedBy';
  static const recurrence = 'recurrence';
}

abstract final class ExpenseMapper {
  static Expense fromFirestore(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      groupId: map[ExpenseFields.groupId] as String,
      title: map[ExpenseFields.title] as String,
      amount: (map[ExpenseFields.amount] as num).toDouble(),
      paidBy: map[ExpenseFields.paidBy] as String,
      paidByName:
          map[ExpenseFields.paidByName] as String? ??
          map[ExpenseFields.paidBy] as String,
      splitWith: FirestoreCodec.stringList(map[ExpenseFields.splitWith]),
      settled: map[ExpenseFields.settled] as bool? ?? false,
      category: map[ExpenseFields.category] as String?,
      date: FirestoreCodec.toDate(map[ExpenseFields.date]),
      createdBy: map[ExpenseFields.createdBy] as String,
      createdAt: FirestoreCodec.toDate(map[ExpenseFields.createdAt]),
      expenseType: ExpenseType.values.byName(
        map[ExpenseFields.expenseType] as String? ?? ExpenseType.expense.name,
      ),
      splitType: SplitType.values.byName(
        map[ExpenseFields.splitType] as String? ?? SplitType.equal.name,
      ),
      splitAmounts: map[ExpenseFields.splitAmounts] == null
          ? null
          : Map<String, double>.from(
              (map[ExpenseFields.splitAmounts] as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, (v as num).toDouble()),
              ),
            ),
      updatedBy: map[ExpenseFields.updatedBy] as String?,
      recurrence: map[ExpenseFields.recurrence] != null
          ? RecurrenceRuleMapper.fromFirestore(
              map[ExpenseFields.recurrence] as Map<String, dynamic>,
            )
          : null,
    );
  }

  static Map<String, dynamic> toFirestore(Expense expense) => {
    ExpenseFields.groupId: expense.groupId,
    ExpenseFields.title: expense.title,
    ExpenseFields.amount: expense.amount,
    ExpenseFields.paidBy: expense.paidBy,
    ExpenseFields.paidByName: expense.paidByName,
    ExpenseFields.splitWith: expense.splitWith,
    ExpenseFields.settled: expense.settled,
    ExpenseFields.category: expense.category,
    ExpenseFields.date: FirestoreCodec.fromDate(expense.date),
    ExpenseFields.createdBy: expense.createdBy,
    ExpenseFields.createdAt: FirestoreCodec.fromDate(expense.createdAt),
    ExpenseFields.expenseType: expense.expenseType.name,
    ExpenseFields.splitType: expense.splitType.name,
    if (expense.splitAmounts != null)
      ExpenseFields.splitAmounts: expense.splitAmounts,
    if (expense.updatedBy != null) ExpenseFields.updatedBy: expense.updatedBy,
    if (expense.recurrence != null)
      ExpenseFields.recurrence: RecurrenceRuleMapper.toFirestore(
        expense.recurrence!,
      ),
  };
}
