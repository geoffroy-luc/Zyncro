import '../models/event.dart';
import '../models/expense.dart';
import '../models/recurrence_rule.dart';

/// Expands recurring events into individual instances within the given window.
/// Non-recurring events are returned as-is.
List<Event> expandEvents(
  List<Event> baseEvents, {
  DateTime? rangeStart,
  DateTime? rangeEnd,
}) {
  final start = rangeStart ?? DateTime.now().subtract(const Duration(days: 365));
  final end = rangeEnd ?? DateTime.now().add(const Duration(days: 730));

  final result = <Event>[];
  for (final event in baseEvents) {
    if (event.recurrence == null) {
      result.add(event);
    } else {
      result.addAll(_expandRecurring(event, start, end));
    }
  }
  result.sort((a, b) => a.startDate.compareTo(b.startDate));
  return result;
}

List<Event> _expandRecurring(Event base, DateTime rangeStart, DateTime rangeEnd) {
  final rule = base.recurrence!;
  final eventDuration = base.endDate != null
      ? base.endDate!.difference(base.startDate)
      : null;

  final instances = <Event>[];
  DateTime current = base.startDate;
  int occurrenceIndex = 0;
  const maxInstances = 1000; // safety cap

  while (occurrenceIndex < maxInstances) {
    // Check rule end conditions
    if (rule.endType == RecurrenceEndType.count &&
        occurrenceIndex >= rule.count!) break;
    if (rule.endType == RecurrenceEndType.until &&
        current.isAfter(rule.until!)) break;
    // Stop generating beyond the display range
    if (current.isAfter(rangeEnd)) break;

    // Only include instances that overlap with the range
    if (!current.isBefore(rangeStart) ||
        (eventDuration != null &&
            current.add(eventDuration).isAfter(rangeStart))) {
      instances.add(Event(
        id: base.id,
        groupId: base.groupId,
        title: base.title,
        description: base.description,
        startDate: current,
        endDate: eventDuration != null ? current.add(eventDuration) : null,
        location: base.location,
        createdBy: base.createdBy,
        creatorName: base.creatorName,
        createdAt: base.createdAt,
        color: base.color,
        updatedBy: base.updatedBy,
        recurrence: base.recurrence,
      ));
    }

    occurrenceIndex++;
    current = _advance(current, rule.frequency);
  }

  return instances;
}

DateTime _advance(DateTime date, RecurrenceFrequency frequency) {
  return switch (frequency) {
    RecurrenceFrequency.daily => date.add(const Duration(days: 1)),
    RecurrenceFrequency.weekly => date.add(const Duration(days: 7)),
    RecurrenceFrequency.monthly =>
      DateTime(date.year, date.month + 1, date.day, date.hour, date.minute),
    RecurrenceFrequency.yearly =>
      DateTime(date.year + 1, date.month, date.day, date.hour, date.minute),
  };
}

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
    if (rule.endType == RecurrenceEndType.count && idx >= rule.count!) break;
    if (rule.endType == RecurrenceEndType.until && current.isAfter(rule.until!)) break;
    if (current.isAfter(now)) break;

    instances.add(Expense(
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
    ));

    idx++;
    current = _advance(current, rule.frequency);
  }

  return instances;
}
