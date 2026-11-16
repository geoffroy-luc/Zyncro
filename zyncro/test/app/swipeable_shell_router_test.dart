import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zyncro/app/swipeable_branches.dart';

/// Même montage que l'app : StatefulShellRoute + SwipeableBranches +
/// branches préchargées.
GoRouter _router() {
  StatefulShellBranch branch(String name) => StatefulShellBranch(
    preload: true,
    routes: [
      GoRoute(
        path: '/$name',
        builder: (_, __) => Scaffold(body: Center(child: Text('page $name'))),
      ),
    ],
  );
  return GoRouter(
    initialLocation: '/a',
    routes: [
      StatefulShellRoute(
        builder: (context, state, shell) => Scaffold(
          body: shell,
          bottomNavigationBar: Row(
            children: [
              for (final (i, label) in ['A', 'B', 'C', 'D'].indexed)
                TextButton(
                  onPressed: () => shell.goBranch(i),
                  child: Text('onglet $label'),
                ),
            ],
          ),
        ),
        navigatorContainerBuilder: (context, shell, children) =>
            SwipeableBranches(
              currentIndex: shell.currentIndex,
              onSwipeTo: shell.goBranch,
              children: children,
            ),
        branches: [branch('a'), branch('b'), branch('c'), branch('d')],
      ),
    ],
  );
}

void main() {
  testWidgets('la barre d’onglets affiche la bonne branche', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
    await tester.pumpAndSettle();
    expect(find.text('page a'), findsOneWidget);

    await tester.tap(find.text('onglet C'));
    await tester.pumpAndSettle();
    expect(find.text('page c'), findsOneWidget);
    expect(find.text('page d'), findsNothing);

    await tester.tap(find.text('onglet B'));
    await tester.pumpAndSettle();
    expect(find.text('page b'), findsOneWidget);
  });

  testWidgets('balayer passe à la branche voisine', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
    await tester.pumpAndSettle();
    await tester.fling(find.text('page a'), const Offset(-500, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('page b'), findsOneWidget);
    await tester.tap(find.text('onglet D'));
    await tester.pumpAndSettle();
    expect(find.text('page d'), findsOneWidget);
    await tester.fling(find.text('page d'), const Offset(500, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('page c'), findsOneWidget);
  });
}
