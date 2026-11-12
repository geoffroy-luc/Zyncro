import 'package:zyncro/features/calendar/domain/entities/event.dart';
import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';

// ⚠️ Comportement historique conservé à l'identique (caractérisé par
// test/characterization/recurrence_utils_test.dart) : occurrences sans
// participantIds, `until` exclusif, plafond de 1000 compté depuis l'ancre
// (BUGS_FOUND K1, K2). Corrections prévues à l'étape 13.

/// Expands recurring events into individual instances within the given window.
/// Non-recurring events are returned as-is.
List<Event> expandEvents(
  List<Event> baseEvents, {
  DateTime? rangeStart,
  DateTime? rangeEnd,
}) {
  final start =
      rangeStart ?? DateTime.now().subtract(const Duration(days: 365));
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

List<Event> _expandRecurring(
  Event base,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final rule = base.recurrence!;
  final eventDuration = base.endDate?.difference(base.startDate);

  final instances = <Event>[];
  DateTime current = base.startDate;
  int occurrenceIndex = 0;
  const maxInstances = 1000; // safety cap

  while (occurrenceIndex < maxInstances) {
    // Check rule end conditions
    if (rule.effectiveEndType == RecurrenceEndType.count &&
        occurrenceIndex >= rule.count!) {
      break;
    }
    if (rule.effectiveEndType == RecurrenceEndType.until &&
        !withinUntil(current, rule.until!)) {
      break;
    }
    // Stop generating beyond the display range
    if (current.isAfter(rangeEnd)) break;

    // Only include instances that overlap with the range
    if (!current.isBefore(rangeStart) ||
        (eventDuration != null &&
            current.add(eventDuration).isAfter(rangeStart))) {
      instances.add(
        Event(
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
          // BUG K2 (2) corrigé : les occurrences gardent leurs participants
          // (le filtre par participant masquait toute la série).
          participantIds: base.participantIds,
          seriesStart: base.startDate,
          occurrenceIndex: occurrenceIndex,
        ),
      );
    }

    occurrenceIndex++;
    current = nthOccurrence(base.startDate, rule.frequency, occurrenceIndex);
  }

  return instances;
}
