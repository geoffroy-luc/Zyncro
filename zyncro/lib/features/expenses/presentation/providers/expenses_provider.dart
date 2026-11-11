import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/core/firebase/firebase_providers.dart';
import 'package:zyncro/features/expenses/data/repositories/expenses_repository.dart';
import 'package:zyncro/features/expenses/domain/repositories/i_expenses_repository.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/shared/models/expense.dart';
import 'package:zyncro/shared/models/group_member.dart';
import 'package:zyncro/shared/utils/recurrence_utils.dart';

final expensesRepositoryProvider = Provider<IExpensesRepository>(
  (ref) => ExpensesRepository(ref.watch(firestoreProvider)),
);

final expensesProvider = StreamProvider<List<Expense>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return Stream.value([]);
  return ref
      .watch(expensesRepositoryProvider)
      .watchExpenses(groupId)
      .map(expandExpenses);
});

final expenseMembersProvider = StreamProvider<List<GroupMember>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return Stream.value([]);
  return ref.watch(groupsRepositoryProvider).watchMembers(groupId);
});

/// Calcule le solde net de chaque membre : positif = on lui doit, négatif = il doit
final balancesProvider = Provider<Map<String, double>>((ref) {
  final expenses = ref.watch(expensesProvider).asData?.value ?? [];
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
});
