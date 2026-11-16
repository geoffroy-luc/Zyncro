import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/expenses/domain/entities/expense.dart';
import 'package:zyncro/features/expenses/presentation/widgets/depenses_tab.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';
import 'package:zyncro/l10n/generated/app_localizations.dart';

final _expense = Expense(
  id: 'e',
  groupId: 'g',
  title: 'Courses',
  amount: 12,
  paidBy: 'a',
  paidByName: 'Alice',
  splitWith: const ['a'],
  settled: false,
  date: DateTime(2026, 11, 10),
  createdBy: 'a',
  createdAt: DateTime(2026, 11, 10),
);

Future<void> _pump(
  WidgetTester tester, {
  required List<Expense> expenses,
  required bool hasAnyExpense,
  required bool searching,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      tabSettingsProvider.overrideWith(
        (ref) => Stream.value(TabSettings.defaults),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DepensesTab(
          expenses: expenses,
          hasAnyExpense: hasAnyExpense,
          searching: searching,
          total: 12,
          myShare: 12,
          currentUid: 'a',
          search: const TextField(key: Key('recherche')),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('la recherche est dans la liste, au-dessus des dépenses', (
    tester,
  ) async {
    await _pump(
      tester,
      expenses: [_expense],
      hasAnyExpense: true,
      searching: false,
    );
    final searchY = tester.getTopLeft(find.byKey(const Key('recherche'))).dy;
    expect(
      searchY,
      greaterThan(tester.getTopLeft(find.text('Aperçu du groupe')).dy),
    );
    expect(searchY, lessThan(tester.getTopLeft(find.text('Courses')).dy));
  });

  testWidgets('aucune dépense dans l’espace : pas de recherche', (
    tester,
  ) async {
    await _pump(tester, expenses: [], hasAnyExpense: false, searching: false);
    expect(find.byKey(const Key('recherche')), findsNothing);
    expect(find.text('Aucune dépense'), findsOneWidget);
  });

  testWidgets('recherche sans résultat : message dédié', (tester) async {
    await _pump(tester, expenses: [], hasAnyExpense: true, searching: true);
    expect(find.byKey(const Key('recherche')), findsOneWidget);
    expect(
      find.text('Aucune dépense ne correspond à la recherche.'),
      findsOneWidget,
    );
    expect(find.text('Aucune dépense'), findsNothing);
  });
}
