import 'dart:math';

/// Remboursement suggéré : [fromUid] doit [amount] à [toUid].
typedef Settlement = ({String fromUid, String toUid, double amount});

/// Plan de remboursement glouton : le plus gros débiteur rembourse le plus
/// gros créancier, jusqu'à épuisement (seuil de 0,01).
List<Settlement> planSettlements(Map<String, double> balances) {
  final creditors =
      balances.entries
          .where((e) => e.value > 0.01)
          .map((e) => MapEntry(e.key, e.value))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
  final debtors =
      balances.entries
          .where((e) => e.value < -0.01)
          .map((e) => MapEntry(e.key, e.value))
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));

  final result = <Settlement>[];
  int ci = 0, di = 0;
  while (ci < creditors.length && di < debtors.length) {
    final credit = creditors[ci].value;
    final debt = debtors[di].value.abs();
    final transfer = min(credit, debt);
    result.add((
      fromUid: debtors[di].key,
      toUid: creditors[ci].key,
      amount: transfer,
    ));
    creditors[ci] = MapEntry(creditors[ci].key, credit - transfer);
    debtors[di] = MapEntry(debtors[di].key, debtors[di].value + transfer);
    if (creditors[ci].value < 0.01) ci++;
    if (debtors[di].value > -0.01) di++;
  }
  return result;
}
