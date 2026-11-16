import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/calendar/presentation/widgets/month_swipe_detector.dart';

void main() {
  late List<String> calls;

  Future<void> pump(WidgetTester tester) async {
    calls = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthSwipeDetector(
            onPrevious: () => calls.add('previous'),
            onNext: () => calls.add('next'),
            child: SizedBox(
              width: 300,
              height: 300,
              child: Center(
                child: TextButton(
                  onPressed: () => calls.add('tap'),
                  child: const Text('15'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('balayer à gauche → mois suivant, à droite → précédent', (
    tester,
  ) async {
    await pump(tester);
    await tester.fling(find.text('15'), const Offset(-200, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.text('15'), const Offset(200, 0), 1000);
    await tester.pumpAndSettle();
    expect(calls, ['next', 'previous']);
  });

  testWidgets('glissé lent ou vertical : pas de changement', (tester) async {
    await pump(tester);
    await tester.timedDrag(
      find.text('15'),
      const Offset(-60, 0),
      const Duration(seconds: 1),
    );
    await tester.fling(find.text('15'), const Offset(0, -200), 1000);
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  });

  testWidgets('un tap sur un jour fonctionne toujours', (tester) async {
    await pump(tester);
    await tester.tap(find.text('15'));
    expect(calls, ['tap']);
  });

  testWidgets('la grille glisse puis affiche le nouveau mois', (tester) async {
    Widget grid(DateTime month, int step) => MaterialApp(
      home: MonthSlideSwitcher(
        month: month,
        step: step,
        child: Text('${month.month}'),
      ),
    );
    await tester.pumpWidget(grid(DateTime(2026, 11), 1));
    await tester.pumpWidget(grid(DateTime(2026, 12), 1));
    await tester.pump(const Duration(milliseconds: 100));
    // Pendant l'animation, les deux mois sont présents…
    expect(find.text('11'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    await tester.pumpAndSettle();
    // … puis seul le nouveau reste.
    expect(find.text('11'), findsNothing);
    expect(find.text('12'), findsOneWidget);
  });
}
