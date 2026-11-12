import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/expenses/domain/entities/expense.dart';
import 'package:zyncro/features/expenses/domain/services/expense_recurrence.dart';
import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';
import 'package:zyncro/shared/domain/recurrence/series_split.dart';

Expense _base(DateTime date, RecurrenceRule rule, {double amount = 10}) =>
    Expense(
      id: 'b',
      groupId: 'g',
      title: 'Loyer',
      amount: amount,
      paidBy: 'a',
      paidByName: 'a',
      splitWith: const ['a', 'b'],
      settled: false,
      date: date,
      createdBy: 'a',
      createdAt: date,
      recurrence: rule,
    );

void main() {
  final anchor = DateTime(2025, 1, 6, 9); // lundi, dans le passé
  const weekly = RecurrenceRule(frequency: RecurrenceFrequency.weekly);

  test('chaque occurrence connaît l’ancre et son rang', () {
    final out = expandExpenses([
      _base(anchor, weekly),
    ]).reversed.take(3).toList();
    expect(out.map((e) => e.occurrenceIndex), [0, 1, 2]);
    expect(out.every((e) => e.seriesStart == anchor), isTrue);
    expect(out[2].isSeriesOccurrence, isTrue);
  });

  test('BUG E8 / E9 corrigés : « celle-ci et les suivantes » coupe la série '
      'sans toucher au passé', () {
    final third = expandExpenses([_base(anchor, weekly)]).reversed.elementAt(2);
    final cut = truncateBefore(
      weekly,
      index: third.occurrenceIndex!,
      occurrence: third.date,
    );
    final old = expandExpenses([_base(third.seriesStart!, cut!)]);
    expect(old.map((e) => e.date).toList().reversed, [
      anchor,
      anchor.add(const Duration(days: 7)),
    ]);

    // La nouvelle série (montant modifié) démarre exactement à l'occurrence.
    final next = expandExpenses([
      _base(third.date, continueFrom(weekly, index: 2), amount: 12),
    ]);
    expect(next.last.date, third.date);
    expect(next.every((e) => e.amount == 12), isTrue);
  });
}
