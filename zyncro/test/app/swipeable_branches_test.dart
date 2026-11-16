import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/app/swipeable_branches.dart';

/// Hôte de test : l'index courant vient « du router » (état parent), comme
/// dans l'app.
class _Host extends StatefulWidget {
  const _Host({required this.swipes});

  final List<int> swipes;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SwipeableBranches(
        currentIndex: index,
        onSwipeTo: (i) {
          widget.swipes.add(i);
          setState(() => index = i);
        },
        children: const [
          Column(
            children: [
              Text('Onglet 0'),
              TextField(key: Key('saisie')),
              Expanded(child: SizedBox.expand()),
            ],
          ),
          Center(child: Text('Onglet 1')),
          Center(child: Text('Onglet 2')),
        ],
      ),
      bottomNavigationBar: TextButton(
        onPressed: () => setState(() => index = 2),
        child: const Text('aller à 2'),
      ),
    );
  }
}

void main() {
  testWidgets('balayer vers la gauche passe à l’onglet suivant', (
    tester,
  ) async {
    final swipes = <int>[];
    await tester.pumpWidget(MaterialApp(home: _Host(swipes: swipes)));
    await tester.fling(find.text('Onglet 0'), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Onglet 1'), findsOneWidget);
    expect(swipes, [1]);

    await tester.fling(find.text('Onglet 1'), const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saisie')), findsOneWidget);
    expect(swipes, [1, 0]);
  });

  testWidgets('changement venu de la barre d’onglets : saut direct, sans '
      'écho', (tester) async {
    final swipes = <int>[];
    await tester.pumpWidget(MaterialApp(home: _Host(swipes: swipes)));
    await tester.tap(find.text('aller à 2'));
    await tester.pumpAndSettle();
    expect(find.text('Onglet 2'), findsOneWidget);
    expect(swipes, isEmpty);
  });

  testWidgets('chaque onglet garde son état', (tester) async {
    final swipes = <int>[];
    await tester.pumpWidget(MaterialApp(home: _Host(swipes: swipes)));
    await tester.enterText(find.byKey(const Key('saisie')), 'brouillon');
    await tester.fling(find.text('Onglet 0'), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    await tester.fling(find.text('Onglet 1'), const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('brouillon'), findsOneWidget);
  });

  testWidgets('balayer puis toucher la barre d’onglets : saut correct', (
    tester,
  ) async {
    final swipes = <int>[];
    await tester.pumpWidget(MaterialApp(home: _Host(swipes: swipes)));
    await tester.fling(find.text('Onglet 0'), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    await tester.fling(find.text('Onglet 1'), const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    await tester.tap(find.text('aller à 2'));
    await tester.pumpAndSettle();
    expect(find.text('Onglet 2'), findsOneWidget);
  });
}
