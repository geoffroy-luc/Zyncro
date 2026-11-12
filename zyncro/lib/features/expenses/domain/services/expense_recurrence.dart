import 'package:zyncro/features/expenses/domain/entities/expense.dart';
import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';

// ⚠️ Comportement historique conservé (BUGS_FOUND E8-E13) : ids
// d'instance instables, `settled` partagé, `now` figé à l'appel.

/// Expands recurring expenses into individual instances up to today.
/// Non-recurring expenses are returned as-is.
List<Expense> expandExpenses(List<Expense> baseExpenses) {
  final now = DateTime.now();
  final result = <Expense>[];
  for (final expense in baseExpenses) {
    if (expense.recurrence == null) {
      result.add(expense);
    } else {
      result.addAll(_expandRecurringExpense(expense, now));
    }
  }
  result.sort((a, b) => b.date.compareTo(a.date));
  return result;
}

List<Expense> _expandRecurringExpense(Expense base, DateTime now) {
  final rule = base.recurrence!;
  final instances = <Expense>[];
  DateTime current = base.date;
  int idx = 0;
  const maxInstances = 500;

  while (idx < maxInstances) {
    if (rule.effectiveEndType == RecurrenceEndType.count &&
        idx >= rule.count!) {
      break;
    }
    if (rule.effectiveEndType == RecurrenceEndType.until &&
        !withinUntil(current, rule.until!)) {
      break;
    }
    if (current.isAfter(now)) break;

    instances.add(
      Expense(
        id: '${base.id}_$idx',
        baseExpenseId: base.id,
        groupId: base.groupId,
        title: base.title,
        amount: base.amount,
        paidBy: base.paidBy,
        paidByName: base.paidByName,
        splitWith: base.splitWith,
        settled: base.settled,
        category: base.category,
        date: current,
        createdBy: base.createdBy,
        createdAt: base.createdAt,
        expenseType: base.expenseType,
        splitType: base.splitType,
        splitAmounts: base.splitAmounts,
        updatedBy: base.updatedBy,
        recurrence: base.recurrence,
        seriesStart: base.date,
        occurrenceIndex: idx,
      ),
    );

    idx++;
    current = nthOccurrence(base.date, rule.frequency, idx);
  }

  return instances;
}
