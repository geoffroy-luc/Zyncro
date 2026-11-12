import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/core/theme/app_theme.dart';
import 'package:zyncro/l10n/generated/app_localizations.dart';
import 'package:zyncro/shared/widgets/color_picker_row.dart';

void main() {
  testWidgets(
    'BUG K3 (a) corrigé : supprimer une couleur depuis un navigator imbriqué',
    (tester) async {
      String? deleted;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('fr'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          // Comme le formulaire poussé dans une branche du shell.
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Column(
                  children: [
                    const Text('Formulaire'),
                    ColorPickerRow(
                      selected: null,
                      onSelect: (_) {},
                      extraColors: const ['#123456'],
                      onDeleteColor: (hex) => deleted = hex,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final custom = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == const Color(0xFF123456),
      );
      expect(custom, findsWidgets);
      await tester.longPress(custom.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();

      expect(deleted, '#123456');
      expect(find.text('Formulaire'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
