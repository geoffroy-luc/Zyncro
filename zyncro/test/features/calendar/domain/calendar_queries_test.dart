import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/calendar/domain/entities/event.dart';
import 'package:zyncro/features/calendar/domain/services/calendar_queries.dart';
import 'package:zyncro/features/calendar/domain/services/event_filter.dart';
import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';

Event ev(
  DateTime start, {
  DateTime? end,
  String title = 't',
  String? location,
  List<String> participants = const [],
  RecurrenceRule? rule,
}) => Event(
  id: title,
  groupId: 'g',
  title: title,
  startDate: start,
  endDate: end,
  location: location,
  createdBy: 'a',
  createdAt: start,
  participantIds: participants,
  recurrence: rule,
);

void main() {
  group('eventOccursOnDay', () {
    test('événement d\'un jour', () {
      final e = ev(DateTime(2026, 11, 2, 9));
      expect(eventOccursOnDay(e, DateTime(2026, 11, 2)), isTrue);
      expect(eventOccursOnDay(e, DateTime(2026, 11, 3)), isFalse);
    });
    test('multi-jours : jours intermédiaires et dernier jour', () {
      final e = ev(DateTime(2026, 10, 28, 10), end: DateTime(2026, 11, 3, 15));
      expect(eventOccursOnDay(e, DateTime(2026, 11)), isTrue);
      expect(eventOccursOnDay(e, DateTime(2026, 11, 3)), isTrue);
      expect(eventOccursOnDay(e, DateTime(2026, 11, 4)), isFalse);
    });
  });

  test(
    'BUG K1 corrigé : un événement à cheval sur deux mois est dans les deux',
    () {
      final e = ev(DateTime(2026, 10, 28), end: DateTime(2026, 11, 3));
      expect(eventsInMonth([e], DateTime(2026, 10)), [e]);
      expect(eventsInMonth([e], DateTime(2026, 11)), [e]);
      expect(eventsInMonth([e], DateTime(2026, 12)), isEmpty);
      final single = ev(DateTime(2026, 11, 30, 23));
      expect(eventsInMonth([single], DateTime(2026, 11)), [single]);
      expect(eventsInMonth([single], DateTime(2026, 12)), isEmpty);
    },
  );

  group('EventFilter', () {
    final a = ev(
      DateTime(2026),
      title: 'Dîner',
      location: 'Paris',
      participants: ['u1'],
    );
    final b = ev(
      DateTime(2026),
      title: 'Sport',
      participants: ['u2'],
      rule: const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
    );
    test('recherche titre et lieu, insensible à la casse', () {
      expect(const EventFilter(search: 'dîn').apply([a, b]), [a]);
      expect(const EventFilter(search: 'PARIS').apply([a, b]), [a]);
    });
    test('participants et récurrence', () {
      expect(const EventFilter(participantIds: {'u2'}).apply([a, b]), [b]);
      expect(const EventFilter(recurrenceOnly: true).apply([a, b]), [b]);
      expect(const EventFilter().apply([a, b]), [a, b]);
    });
  });
}
