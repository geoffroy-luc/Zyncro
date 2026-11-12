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

/// Événements du mois affiché : tous ceux qui **chevauchent** le mois.
///
/// BUG K1 corrigé : auparavant seul le mois de début comptait (un événement
/// du 28/10 au 03/11 était absent de novembre).
List<Event> eventsInMonth(Iterable<Event> events, DateTime month) {
  final first = DateTime(month.year, month.month);
  final next = DateTime(month.year, month.month + 1);
  return events
      .where(
        (e) =>
            e.startDate.isBefore(next) &&
            !(e.endDate ?? e.startDate).isBefore(first),
      )
      .toList();
}
