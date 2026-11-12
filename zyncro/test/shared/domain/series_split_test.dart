import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';
import 'package:zyncro/shared/domain/recurrence/series_split.dart';

void main() {
  const weekly = RecurrenceRule(frequency: RecurrenceFrequency.weekly);
  final occ = DateTime(2026, 11, 16, 9);

  test('arrêt avant l’occurrence : until juste avant, count = index', () {
    final cut = truncateBefore(weekly, index: 2, occurrence: occ)!;
    expect(cut.endType, RecurrenceEndType.until);
    expect(cut.until, DateTime(2026, 11, 15, 23, 59, 59));
    final byCount = truncateBefore(
      const RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        endType: RecurrenceEndType.count,
        count: 10,
      ),
      index: 3,
      occurrence: occ,
    )!;
    expect(byCount.count, 3);
    expect(truncateBefore(weekly, index: 0, occurrence: occ), isNull);
  });

  test('suite de série : nombre restant pour count, sinon même règle', () {
    const ten = RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      endType: RecurrenceEndType.count,
      count: 10,
    );
    expect(continueFrom(ten, index: 3).count, 7);
    expect(identical(continueFrom(weekly, index: 3), weekly), isTrue);
  });

  test('BUG K2 / E8 corrigés : éditer l’occurrence du 16/11 garde l’ancre', () {
    final anchor = DateTime(2026, 11, 2, 9);
    expect(shiftAnchor(anchor, occurrence: occ, edited: occ), anchor);
    // Occurrence déplacée d'une heure : toute la série l'est aussi.
    expect(
      shiftAnchor(
        anchor,
        occurrence: occ,
        edited: occ.add(const Duration(hours: 1)),
      ),
      DateTime(2026, 11, 2, 10),
    );
  });
}
