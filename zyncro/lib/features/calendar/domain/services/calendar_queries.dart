import 'package:zyncro/features/calendar/domain/entities/event.dart';

/// Même jour calendaire (heure ignorée).
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// L'événement a lieu ce jour-là : il commence ce jour, ou il a commencé
/// avant et se termine ce jour ou après.
bool eventOccursOnDay(Event e, DateTime day) =>
    isSameDay(e.startDate, day) ||
    (e.endDate != null &&
        !e.startDate.isAfter(day) &&
        !e.endDate!.isBefore(day));

/// Événements du mois affiché.
///
/// ⚠️ Ne retient que les événements qui COMMENCENT dans le mois : un événement
/// à cheval sur deux mois est absent du second (BUGS_FOUND K1) — comportement
/// historique conservé.
List<Event> eventsStartingInMonth(Iterable<Event> events, DateTime month) =>
    events
        .where(
          (e) =>
              e.startDate.year == month.year &&
              e.startDate.month == month.month,
        )
        .toList();
