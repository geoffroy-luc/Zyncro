import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/core/firebase/firebase_providers.dart';
import 'package:zyncro/features/expenses/data/repositories/firestore_expenses_repository.dart';
import 'package:zyncro/features/expenses/domain/entities/expense.dart';
import 'package:zyncro/features/expenses/domain/repositories/expenses_repository.dart';
import 'package:zyncro/features/expenses/domain/services/balance_calculator.dart';
import 'package:zyncro/features/expenses/domain/services/expense_recurrence.dart';
import 'package:zyncro/features/groups/domain/entities/group_member.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>(
  (ref) => FirestoreExpensesRepository(ref.watch(firestoreProvider)),
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
  return computeBalances(expenses);
});
