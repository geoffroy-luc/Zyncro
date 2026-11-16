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

  testWidgets('changement venu de la barre d’onglets : sans écho', (
    tester,
  ) async {
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

  testWidgets('onglets internes : relais aux onglets de l’app aux bords', (
    tester,
  ) async {
    final swipes = <int>[];
    var index = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: SwipeableBranches(
              currentIndex: index,
              onSwipeTo: (i) {
                swipes.add(i);
                setState(() => index = i);
              },
              children: [
                const Center(child: Text('Notes')),
                // Comme Dépenses / Équilibre : pages internes à bords francs.
                PageView(
                  physics: const PageScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  children: const [
                    Center(child: Text('Dépenses')),
                    Center(child: Text('Équilibre')),
                  ],
                ),
                const Center(child: Text('Chat')),
              ],
            ),
          ),
        ),
      ),
    );

    // Notes → onglet Dépenses (page interne 1).
    await tester.fling(find.text('Notes'), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Dépenses'), findsOneWidget);

    // Dans l'onglet : Dépenses → Équilibre (interne, pas de changement
    // d'onglet de l'app).
    await tester.fling(find.text('Dépenses'), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Équilibre'), findsOneWidget);
    expect(swipes, [1]);

    // Au bord droit : le balayage passe au Chat.
    await tester.fling(find.text('Équilibre'), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Chat'), findsOneWidget);
    expect(swipes, [1, 2]);

    // Retour : Chat → Équilibre, puis Équilibre → Dépenses (interne), puis
    // au bord gauche → Notes.
    await tester.fling(find.text('Chat'), const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Équilibre'), findsOneWidget);
    await tester.fling(find.text('Équilibre'), const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Dépenses'), findsOneWidget);
    await tester.fling(find.text('Dépenses'), const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsOneWidget);
    expect(swipes, [1, 2, 1, 0]);
  });

  testWidgets('relais : petit glissé au bord, on revient sur l’onglet', (
    tester,
  ) async {
    final swipes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SwipeableBranches(
          currentIndex: 0,
          onSwipeTo: swipes.add,
          children: [
            PageView(
              physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
              children: const [
                Center(child: Text('Dépenses')),
                Center(child: Text('Équilibre')),
              ],
            ),
            const Center(child: Text('Chat')),
          ],
        ),
      ),
    );
    await tester.fling(find.text('Dépenses'), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    // Glissé lent et court au bord : pas assez pour changer d'onglet.
    await tester.timedDrag(
      find.text('Équilibre'),
      const Offset(-60, 0),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    expect(find.text('Équilibre'), findsOneWidget);
    expect(swipes, isEmpty);
  });

  testWidgets('relais sur écran étroit : un seul onglet par balayage', (
    tester,
  ) async {
    // Largeur d'un téléphone : un balayage de 400 px dépasse la page.
    tester.view.physicalSize = const Size(393, 851);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final swipes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SwipeableBranches(
          currentIndex: 2,
          onSwipeTo: swipes.add,
          children: [
            const Center(child: Text('Calendrier')),
            const Center(child: Text('Notes')),
            PageView(
              physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
              children: const [
                Center(child: Text('Dépenses')),
                Center(child: Text('Équilibre')),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.fling(find.text('Dépenses'), const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsOneWidget);
    expect(swipes, [1]);
  });

  group('barre d’onglets : transition animée', () {
    late int index;
    late List<int> swipes;

    Future<void> pump(WidgetTester tester) async {
      index = 0;
      swipes = [];
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SwipeableBranches(
                currentIndex: index,
                onSwipeTo: swipes.add,
                children: [
                  for (final name in ['A', 'B', 'C', 'D'])
                    Center(child: Text('page $name')),
                ],
              ),
              bottomNavigationBar: Row(
                children: [
                  for (final (i, name) in ['A', 'B', 'C', 'D'].indexed)
                    TextButton(
                      onPressed: () => setState(() => index = i),
                      child: Text('onglet $name'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('onglet voisin : la page glisse', (tester) async {
      await pump(tester);
      await tester.tap(find.text('onglet B'));
      await tester.pump(); // post-frame : lancement de l'animation
      await tester.pump(); // premier tick : origine du temps de l'animation
      await tester.pump(const Duration(milliseconds: 120));
      // En pleine glissade, les deux pages sont à l'écran.
      expect(find.text('page A'), findsOneWidget);
      expect(find.text('page B'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('page A'), findsNothing);
      expect(swipes, isEmpty);
    });

    testWidgets('onglet éloigné : fondu, sans traverser les autres', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('onglet D'));
      await tester.pump(); // post-frame : lancement du fondu
      await tester.pump(); // premier tick
      await tester.pump(const Duration(milliseconds: 60));
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(PageView),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, lessThan(1));
      // Jamais de page B / C affichée pendant le saut.
      expect(find.text('page B'), findsNothing);
      expect(find.text('page C'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('page D'), findsOneWidget);
      expect(fade.opacity.value, 1);
      expect(swipes, isEmpty);
    });
  });
}
