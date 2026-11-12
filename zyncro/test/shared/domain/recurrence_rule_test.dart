import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/calendar/domain/entities/event.dart';
import 'package:zyncro/features/calendar/domain/services/event_recurrence.dart';
import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';
import 'package:zyncro/shared/presentation/recurrence_rule_label.dart';

void main() {
  test('BUG E15 corrigé : règle incohérente lue comme sans fin', () {
    const noCount = RecurrenceRule(
      frequency: RecurrenceFrequency.daily,
      endType: RecurrenceEndType.count,
    );
    const noUntil = RecurrenceRule(
      frequency: RecurrenceFrequency.daily,
      endType: RecurrenceEndType.until,
    );
    expect(noCount.effectiveEndType, RecurrenceEndType.forever);
    expect(noUntil.effectiveEndType, RecurrenceEndType.forever);
    expect(noUntil.label, 'Tous les jours');

    final start = DateTime(2026, 11, 1, 9);
    final out = expandEvents(
      [
        Event(
          id: 'e',
          groupId: 'g',
          title: 't',
          startDate: start,
          createdBy: 'a',
          createdAt: start,
          recurrence: noCount,
        ),
      ],
      rangeStart: start,
      rangeEnd: DateTime(2026, 11, 5),
    );
    expect(out.length, 4);
  });
}
