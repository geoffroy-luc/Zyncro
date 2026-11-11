// Caractérisation des providers à logique pure (soldes, ordre des groupes)
// et du parsing des liens d'invitation, TELS QU'ILS SONT.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/core/constants/invite.dart';
import 'package:zyncro/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/shared/models/expense.dart';
import 'package:zyncro/shared/models/group.dart';

Expense exp({
  required String paidBy,
  required double amount,
  required List<String> splitWith,
  Map<String, double>? splitAmounts,
  bool settled = false,
  ExpenseType type = ExpenseType.expense,
}) => Expense(
  id: 'x${amount.hashCode}$paidBy',
  groupId: 'g',
  title: 't',
  amount: amount,
  paidBy: paidBy,
  paidByName: paidBy,
  splitWith: splitWith,
  settled: settled,
  date: DateTime(2026),
  createdBy: paidBy,
  createdAt: DateTime(2026),
  expenseType: type,
  splitAmounts: splitAmounts,
);

Future<Map<String, double>> balancesOf(List<Expense> expenses) async {
  final container = ProviderContainer(
    overrides: [expensesProvider.overrideWith((ref) => Stream.value(expenses))],
  );
  addTearDown(container.dispose);
  container.listen(expensesProvider, (_, _) {});
  await container.read(expensesProvider.future);
  return container.read(balancesProvider);
}

void main() {
  group('balancesProvider', () {
    test('parts égales', () async {
      final b = await balancesOf([
        exp(paidBy: 'a', amount: 30, splitWith: ['a', 'b', 'c']),
      ]);
      expect(b, {'a': 20.0, 'b': -10.0, 'c': -10.0});
    });

    test('payeur hors répartition', () async {
      final b = await balancesOf([
        exp(paidBy: 'a', amount: 20, splitWith: ['b', 'c']),
      ]);
      expect(b, {'a': 20.0, 'b': -10.0, 'c': -10.0});
    });

    test('montants personnalisés', () async {
      final b = await balancesOf([
        exp(
          paidBy: 'a',
          amount: 50,
          splitWith: ['a', 'b'],
          splitAmounts: {'a': 10, 'b': 40},
        ),
      ]);
      expect(b, {'a': 40.0, 'b': -40.0});
    });

    test('dépenses soldées ignorées', () async {
      final b = await balancesOf([
        exp(paidBy: 'a', amount: 30, splitWith: ['a', 'b'], settled: true),
      ]);
      expect(b, isEmpty);
    });

    test('un remboursement annule la dette', () async {
      final b = await balancesOf([
        exp(paidBy: 'a', amount: 30, splitWith: ['a', 'b']),
        exp(
          paidBy: 'b',
          amount: 15,
          splitWith: ['a'],
          splitAmounts: {'a': 15},
          type: ExpenseType.reimbursement,
        ),
      ]);
      expect(b, {'a': 0.0, 'b': 0.0});
    });

    test('BUG E2 : répartition en % non normalisée → soldes ≠ 0', () async {
      // 70 € / 7 en % saisis à 14,29 % (EXF stocke total * pct / 100)
      final pctAmounts = {
        for (final u in ['a', 'b', 'c', 'd', 'e', 'f', 'g'])
          u: 70 * 14.29 / 100,
      };
      final b = await balancesOf([
        exp(
          paidBy: 'a',
          amount: 70,
          splitWith: pctAmounts.keys.toList(),
          splitAmounts: pctAmounts,
        ),
      ]);
      final sum = b.values.fold<double>(0, (s, v) => s + v);
      expect(sum, isNot(closeTo(0, 0.001)));
    });
  });

  group('orderedGroupsProvider', () {
    Group g(String id) => Group(
      id: id,
      name: id,
      memberIds: const ['u'],
      createdBy: 'u',
      createdAt: DateTime(2026),
    );

    Future<List<String>> ordered(List<Group> groups, List<String> order) async {
      final container = ProviderContainer(
        overrides: [
          userGroupsProvider.overrideWith((ref) => Stream.value(groups)),
          groupOrderProvider.overrideWith(() => _FixedOrder(order)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(userGroupsProvider, (_, _) {});
      container.listen(groupOrderProvider, (_, _) {});
      await container.read(userGroupsProvider.future);
      await container.read(groupOrderProvider.future);
      return container.read(orderedGroupsProvider).map((e) => e.id).toList();
    }

    test('sans préférence : ordre Firestore', () async {
      expect(await ordered([g('a'), g('b'), g('c')], []), ['a', 'b', 'c']);
    });

    test('préférence appliquée, groupes inconnus en fin', () async {
      expect(await ordered([g('a'), g('b'), g('c')], ['c', 'a']), [
        'c',
        'a',
        'b',
      ]);
    });
  });

  group('InviteLink', () {
    test('forCode', () {
      expect(
        InviteLink.forCode(' ab4k9p '),
        'https://zyncro-f5fdd.web.app/i/AB4K9P',
      );
    });
    test('codeFromUri : App Link, Universal Link, schéma perso', () {
      expect(
        InviteLink.codeFromUri(
          Uri.parse('https://zyncro-f5fdd.web.app/i/ab4k9p'),
        ),
        'AB4K9P',
      );
      expect(InviteLink.codeFromUri(Uri.parse('zyncro://i/xy23zz')), 'XY23ZZ');
      expect(
        InviteLink.codeFromUri(Uri.parse('https://x.app/autre/abc')),
        isNull,
      );
      expect(InviteLink.codeFromUri(Uri.parse('zyncro://i')), isNull);
    });
  });
}

class _FixedOrder extends GroupOrderNotifier {
  _FixedOrder(this._order);
  final List<String> _order;
  @override
  Future<List<String>> build() async => _order;
}
