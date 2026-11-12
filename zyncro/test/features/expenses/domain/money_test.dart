import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/expenses/domain/services/money.dart';

void main() {
  test('BUG E1 corrigé : 100 € / 3 au centime, somme exacte', () {
    final s = allocateCents(10000, {'a': 1.0, 'b': 1.0, 'c': 1.0});
    expect(s, {'a': 3334, 'b': 3333, 'c': 3333});
    expect(s.values.reduce((x, y) => x + y), 10000);
  });

  test('BUG E2 corrigé : % arrondis normalisés sur le total', () {
    final s = allocateCents(7000, {
      for (final u in ['a', 'b', 'c', 'd', 'e', 'f', 'g']) u: 14.29,
    });
    expect(s.values.toSet(), {1000});
  });

  test('BUG E3 corrigé : réenregistrer sans rien toucher ne change rien', () {
    // Montants stockés → % affichés (2 décimales) → montants recalculés.
    const total = 100.0;
    final stored = {'a': 33.34, 'b': 33.33, 'c': 33.33};
    final pcts = stored.map(
      (k, v) => MapEntry(k, double.parse((v / total * 100).toStringAsFixed(2))),
    );
    final again = allocateCents(
      toCents(total),
      pcts,
    ).map((k, c) => MapEntry(k, fromCents(c)));
    expect(again, stored);
  });

  test('poids nuls ou négatifs, total négatif', () {
    expect(allocateCents(500, {'a': 0.0, 'b': 0.0}), {'a': 0, 'b': 0});
    expect(allocateCents(500, {'a': -1.0, 'b': 1.0}), {'a': 0, 'b': 500});
    expect(allocateCents(-1000, {'a': 1.0, 'b': 1.0, 'c': 1.0}), {
      'a': -334,
      'b': -333,
      'c': -333,
    });
  });
}
