/// Calculs monétaires en centimes entiers (les montants restent stockés en
/// `double` d'euros dans Firestore : format inchangé).
int toCents(double euros) => (euros * 100).round();

double fromCents(int cents) => cents / 100;

/// Répartit [totalCents] proportionnellement à [weights] (méthode du plus
/// fort reste) : la somme du résultat vaut **exactement** [totalCents].
/// À égalité de reste, l'ordre d'itération de [weights] départage (stable).
/// Poids négatifs ignorés ; somme des poids nulle → parts nulles.
Map<K, int> allocateCents<K>(int totalCents, Map<K, double> weights) {
  final keys = weights.keys.toList();
  final w = [for (final k in keys) weights[k]! > 0 ? weights[k]! : 0.0];
  final sumW = w.fold(0.0, (a, b) => a + b);
  if (sumW <= 0 || keys.isEmpty) return {for (final k in keys) k: 0};
  final sign = totalCents < 0 ? -1 : 1;
  final total = totalCents.abs();
  final raw = [for (final x in w) total * x / sumW];
  final cents = [for (final r in raw) r.floor()];
  var rest = total - cents.fold(0, (a, b) => a + b);
  final order = List<int>.generate(keys.length, (i) => i)
    ..sort((a, b) {
      final fa = raw[a] - cents[a];
      final fb = raw[b] - cents[b];
      final byFraction = fb.compareTo(fa);
      return byFraction != 0 ? byFraction : a.compareTo(b);
    });
  for (final i in order) {
    if (rest == 0) break;
    if (w[i] == 0) continue;
    cents[i]++;
    rest--;
  }
  return {for (var i = 0; i < keys.length; i++) keys[i]: sign * cents[i]};
}
