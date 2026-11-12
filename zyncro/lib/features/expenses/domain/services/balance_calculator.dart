import 'package:zyncro/features/expenses/domain/entities/expense.dart';

/// Solde net de chaque membre : positif = on lui doit, négatif = il doit.
///
/// Les dépenses soldées (`settled`) sont ignorées ; le payeur avance le
/// montant total, chaque participant doit sa part (`effectiveSplitAmounts`).
/// ⚠️ Montants en double et parts en % non normalisées : la somme des soldes
/// peut différer de 0 (BUGS_FOUND E2) — comportement historique conservé.
Map<String, double> computeBalances(Iterable<Expense> expenses) {
  final balances = <String, double>{};
  for (final expense in expenses.where((e) => !e.settled)) {
    final splitAmounts = expense.effectiveSplitAmounts;
    // Le payeur avance pour tout le monde
    balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + expense.amount;
    // Chaque participant doit sa part
    for (final entry in splitAmounts.entries) {
      balances[entry.key] = (balances[entry.key] ?? 0) - entry.value;
    }
  }
  return balances;
}
