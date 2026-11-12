import 'package:zyncro/features/expenses/domain/entities/expense.dart';
import 'package:zyncro/features/expenses/domain/services/money.dart';

/// Solde net de chaque membre : positif = on lui doit, négatif = il doit.
///
/// Les dépenses soldées (`settled`) sont ignorées ; le payeur avance le
/// montant total, chaque participant doit sa part (`effectiveSplitAmounts`).
///
/// BUG E2 / E5 corrigés : chaque dépense est répartie **en centimes**,
/// proportionnellement aux parts stockées et normalisée sur son montant. La
/// somme des soldes vaut exactement 0 (plus de « -0,00 € »), y compris pour
/// les dépenses déjà enregistrées avec des % non normalisés (Σ = 70,021 €).
Map<String, double> computeBalances(Iterable<Expense> expenses) {
  final cents = <String, int>{};
  for (final expense in expenses.where((e) => !e.settled)) {
    final total = toCents(expense.amount);
    // Le payeur avance pour tout le monde
    cents[expense.paidBy] = (cents[expense.paidBy] ?? 0) + total;
    // Chaque participant doit sa part
    final shares = allocateCents(total, expense.effectiveSplitAmounts);
    for (final entry in shares.entries) {
      cents[entry.key] = (cents[entry.key] ?? 0) - entry.value;
    }
  }
  return cents.map((uid, c) => MapEntry(uid, fromCents(c)));
}
