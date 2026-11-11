// Caractérisation de shared/utils/recurrence_utils.dart TEL QU'IL EST, bugs
// compris (BUGS_FOUND K1, K2, E10-E13). Les tests marqués « BUG » seront
// inversés quand le correctif sera validé (étape 13).
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/shared/models/event.dart';
import 'package:zyncro/shared/models/expense.dart';
import 'package:zyncro/shared/models/recurrence_rule.dart';
import 'package:zyncro/shared/utils/recurrence_utils.dart';

Event event(
  DateTime start, {
  DateTime? end,
  RecurrenceRule? rule,
  List<String> participants = const [],
  String id = 'e1',
}) => Event(
  id: id,
  groupId: 'g',
  title: 't',
  startDate: start,
  endDate: end,
  createdBy: 'a',
  createdAt: start,
  recurrence: rule,
  participantIds: participants,
);

Expense expense(DateTime date, {RecurrenceRule? rule, bool settled = false}) =>
    Expense(
      id: 'x1',
      groupId: 'g',
      title: 'Loyer',
      amount: 500,
      paidBy: 'a',
      paidByName: 'A',
      splitWith: const ['a', 'b'],
      settled: settled,
      date: date,
      createdBy: 'a',
      createdAt: date,
      recurrence: rule,
    );

final window = (start: DateTime(2026), end: DateTime(2027));

List<DateTime> starts(List<Event> events) =>
    events.map((e) => e.startDate).toList();

void main() {
  group('expandEvents', () {
    test('événement ponctuel renvoyé tel quel, tri par date', () {
      final a = event(DateTime(2026, 5, 2), id: 'a');
      final b = event(DateTime(2026, 5), id: 'b');
      final out = expandEvents(
        [a, b],
        rangeStart: window.start,
        rangeEnd: window.end,
      );
      expect(out.map((e) => e.id), ['b', 'a']);
      expect(identical(out[1], a), isTrue);
    });

    test('hebdomadaire avec count', () {
      final out = expandEvents(
        [
          event(
            DateTime(2026, 11, 2, 9),
            rule: const RecurrenceRule(
              frequency: RecurrenceFrequency.weekly,
              endType: RecurrenceEndType.count,
              count: 3,
            ),
          ),
        ],
        rangeStart: window.start,
        rangeEnd: window.end,
      );
      expect(starts(out).map((d) => d.day), [2, 9, 16]);
      expect(out.every((e) => e.id == 'e1'), isTrue);
    });

    test('durée conservée sur chaque occurrence', () {
      final out = expandEvents(
        [
          event(
            DateTime(2026, 6, 1, 10),
            end: DateTime(2026, 6, 1, 12),
            rule: const RecurrenceRule(
              frequency: RecurrenceFrequency.daily,
              endType: RecurrenceEndType.count,
              count: 2,
            ),
          ),
        ],
        rangeStart: window.start,
        rangeEnd: window.end,
      );
      expect(
        out.map((e) => e.endDate!.difference(e.startDate)),
        everyElement(const Duration(hours: 2)),
      );
    });

    test('occurrences hors fenêtre exclues, chevauchement inclus', () {
      final out = expandEvents(
        [
          event(
            DateTime(2025, 12, 31, 23),
            end: DateTime(2026, 1, 1, 1),
            rule: const RecurrenceRule(
              frequency: RecurrenceFrequency.daily,
              endType: RecurrenceEndType.count,
              count: 3,
            ),
          ),
        ],
        rangeStart: window.start,
        rangeEnd: window.end,
      );
      expect(starts(out), [
        DateTime(2025, 12, 31, 23),
        DateTime(2026, 1, 1, 23),
        DateTime(2026, 1, 2, 23),
      ]);
    });

    test('BUG K1 : dérive mensuelle à partir du 31', () {
      final out = expandEvents(
        [
          event(
            DateTime(2026, 1, 31, 9),
            rule: const RecurrenceRule(
              frequency: RecurrenceFrequency.monthly,
              endType: RecurrenceEndType.count,
              count: 4,
            ),
          ),
        ],
        rangeStart: window.start,
        rangeEnd: window.end,
      );
      expect(starts(out), [
        DateTime(2026, 1, 31, 9),
        DateTime(2026, 3, 3, 9),
        DateTime(2026, 4, 3, 9),
        DateTime(2026, 5, 3, 9),
      ]);
    });

    test('BUG : 29 février annuel → 1er mars puis dérive', () {
      final out = expandEvents(
        [
          event(
            DateTime(2024, 2, 29),
            rule: const RecurrenceRule(
              frequency: RecurrenceFrequency.yearly,
              endType: RecurrenceEndType.count,
              count: 3,
            ),
          ),
        ],
        rangeStart: DateTime(2024),
        rangeEnd: DateTime(2030),
      );
      expect(starts(out), [
        DateTime(2024, 2, 29),
        DateTime(2025, 3),
        DateTime(2026, 3),
      ]);
    });

    test('BUG K2 : until à minuit exclut le dernier jour', () {
      final out = expandEvents(
        [
          event(
            DateTime(2026, 11, 2, 9),
            rule: RecurrenceRule(
              frequency: RecurrenceFrequency.weekly,
              endType: RecurrenceEndType.until,
              until: DateTime(2026, 11, 16),
            ),
          ),
        ],
        rangeStart: window.start,
        rangeEnd: window.end,
      );
      expect(starts(out).map((d) => d.day), [2, 9]);
    });

    test('BUG K2 : les occurrences perdent participantIds', () {
      final out = expandEvents(
        [
          event(
            DateTime(2026, 11, 2),
            participants: const ['a', 'b'],
            rule: const RecurrenceRule(
              frequency: RecurrenceFrequency.daily,
              endType: RecurrenceEndType.count,
              count: 2,
            ),
          ),
        ],
        rangeStart: window.start,
        rangeEnd: window.end,
      );
      expect(out.map((e) => e.participantIds), everyElement(isEmpty));
    });

    test('forever : arrêt à la fin de la fenêtre', () {
      final out = expandEvents(
        [
          event(
            DateTime(2026, 12, 25),
            rule: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
          ),
        ],
        rangeStart: window.start,
        rangeEnd: window.end,
      );
      expect(out.length, 8); // 25 → 31 décembre + 1er janvier 00:00
      expect(out.last.startDate, DateTime(2027));
    });

    test('BUG K2 : plafond de 1000 compté depuis l\'ancre', () {
      final out = expandEvents(
        [
          event(
            DateTime(2020),
            rule: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
          ),
        ],
        rangeStart: window.start,
        rangeEnd: window.end,
      );
      expect(out, isEmpty); // 1000 jours depuis 2020 < 2026
    });
  });

  group('expandExpenses', () {
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, 1, 12);

    test('dépense ponctuelle renvoyée telle quelle, tri décroissant', () {
      final a = expense(DateTime(2026));
      final out = expandExpenses([a]);
      expect(identical(out.single, a), isTrue);
    });

    test('mensuelle : instances jusqu\'à aujourd\'hui, ids instables', () {
      final out = expandExpenses([
        expense(
          threeMonthsAgo,
          rule: const RecurrenceRule(frequency: RecurrenceFrequency.monthly),
        ),
      ]);
      expect(out.length, 4); // M-3, M-2, M-1, M (1er du mois ≤ maintenant)
      expect(out.first.date.isAfter(out.last.date), isTrue);
      expect(out.map((e) => e.id).toSet(), {'x1_0', 'x1_1', 'x1_2', 'x1_3'});
      expect(out.map((e) => e.firestoreId), everyElement('x1'));
    });

    test('BUG E10 : settled partagé par toutes les instances', () {
      final out = expandExpenses([
        expense(
          threeMonthsAgo,
          settled: true,
          rule: const RecurrenceRule(frequency: RecurrenceFrequency.monthly),
        ),
      ]);
      expect(out.map((e) => e.settled), everyElement(isTrue));
    });

    test('count respecté', () {
      final out = expandExpenses([
        expense(
          threeMonthsAgo,
          rule: const RecurrenceRule(
            frequency: RecurrenceFrequency.monthly,
            endType: RecurrenceEndType.count,
            count: 2,
          ),
        ),
      ]);
      expect(out.length, 2);
    });

    test('date future : aucune instance', () {
      final out = expandExpenses([
        expense(
          now.add(const Duration(days: 10)),
          rule: const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
        ),
      ]);
      expect(out, isEmpty);
    });
  });
}
