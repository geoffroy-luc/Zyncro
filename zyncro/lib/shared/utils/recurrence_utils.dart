import '../models/event.dart';
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
