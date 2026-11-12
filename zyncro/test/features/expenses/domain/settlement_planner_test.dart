import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/expenses/domain/services/settlement_planner.dart';

void main() {
  test('tout équilibré → aucun remboursement', () {
    expect(planSettlements({}), isEmpty);
    expect(planSettlements({'a': 0, 'b': 0.005, 'c': -0.009}), isEmpty);
  });

  test('un créancier, deux débiteurs → deux virements', () {
    final plan = planSettlements({'a': 30, 'b': -10, 'c': -20});
    expect(plan, [
      (fromUid: 'c', toUid: 'a', amount: 20.0),
      (fromUid: 'b', toUid: 'a', amount: 10.0),
    ]);
  });

  test('chaîne de créances', () {
    final plan = planSettlements({'a': 50, 'b': 10, 'c': -40, 'd': -20});
    final total = plan.fold<double>(0, (s, t) => s + t.amount);
    expect(total, closeTo(60, 1e-9));
    expect(plan.first, (fromUid: 'c', toUid: 'a', amount: 40.0));
  });

  test('résidu sous le seuil ignoré', () {
    final plan = planSettlements({'a': 10.004, 'b': -10});
    expect(plan, [(fromUid: 'b', toUid: 'a', amount: 10.0)]);
  });
}
