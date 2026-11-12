import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/expenses/data/mappers/expense_mapper.dart';
import 'package:zyncro/features/expenses/domain/entities/expense.dart';

void main() {
  test('BUG E17 corrigé : retirer la catégorie écrit null', () {
    final e = Expense(
      id: 'x',
      groupId: 'g',
      title: 't',
      amount: 10,
      paidBy: 'a',
      paidByName: 'a',
      splitWith: const ['a'],
      settled: false,
      category: 'Courses',
      date: DateTime(2026),
      createdBy: 'a',
      createdAt: DateTime(2026),
    );
    final cleared = e.copyWith(clearCategory: true);
    expect(cleared.category, isNull);
    expect(ExpenseMapper.toFirestore(cleared)['category'], isNull);
    expect(e.copyWith().category, 'Courses');
  });
}
