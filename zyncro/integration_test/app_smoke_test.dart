// Test de bout en bout : l'app réelle, sur un appareil / émulateur Android,
// contre les émulateurs Firebase locaux (rules du dépôt chargées).
//
// Lancement (voir docs/ARCHITECTURE.md, « Tests de bout en bout ») :
//   firebase emulators:start --only auth,firestore,storage --project zyncro-f5fdd
//   flutter test integration_test/app_smoke_test.dart \
//     --dart-define=USE_FIREBASE_EMULATORS=true -d <device>
//
// Parcours couvert = checklist de non-régression (PLAN annexe A) : invité,
// création d'espace, note, événement, dépense, message, navigation entre
// onglets. Chaque écriture passe par les rules réelles.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zyncro/core/firebase/firebase_emulators.dart';
import 'package:zyncro/core/navigation/app_routes.dart';
import 'package:zyncro/main.dart' as app;

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  // Diagnostic : textes visibles au moment de l'échec.
  final visible = find
      .byType(Text)
      .evaluate()
      .map(
        (e) =>
            (e.widget as Text).data ??
            (e.widget as Text).textSpan?.toPlainText(),
      )
      .whereType<String>()
      .where((t) => t.trim().isNotEmpty)
      .toSet()
      .join(' | ');
  throw TestFailure(
    'Introuvable après $timeout : $finder\nTextes visibles : $visible',
  );
}

Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Toujours présent après $timeout : $finder');
}

Future<void> tapAndPump(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 500));
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

Finder fab() => find.descendant(
  of: find.byType(FloatingActionButton),
  matching: find.byIcon(Icons.add),
);

Finder navTab(String label) => find.text(label).last;

Future<void> save(WidgetTester tester) async {
  await tapAndPump(tester, find.byIcon(Icons.check).last);
  await pumpUntilGone(tester, field('Titre'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('parcours complet invité → espace → 4 onglets', (tester) async {
    expect(
      useFirebaseEmulators,
      isTrue,
      reason:
          'Refus de tourner contre la production : '
          'ajouter --dart-define=USE_FIREBASE_EMULATORS=true',
    );
    final suffix = DateTime.now().millisecondsSinceEpoch % 100000;
    final groupName = 'E2E $suffix';

    app.main();

    // ── Connexion invité ──────────────────────────────────────────────────
    await pumpUntil(tester, find.text('Continuer sans compte'));
    await tapAndPump(tester, find.text('Continuer sans compte').first);
    await pumpUntil(tester, field('Pseudo'));
    await tester.enterText(field('Pseudo'), 'Testeur');
    await tapAndPump(tester, find.widgetWithText(ElevatedButton, 'Continuer'));

    // ── Création d'un espace ──────────────────────────────────────────────
    await pumpUntil(tester, find.text('Créer un espace'));
    await tapAndPump(tester, find.text('Créer un espace'));
    await pumpUntil(tester, field("Nom de l'espace"));
    await tester.enterText(field("Nom de l'espace"), groupName);
    await tapAndPump(tester, find.widgetWithText(ElevatedButton, 'Créer').last);

    await pumpUntilGone(tester, field("Nom de l'espace"));
    // Selon le timing, l'app ouvre directement l'espace créé ou reste sur la
    // liste « Mes espaces » : on accepte les deux.
    final dashboard = find.text('Prochains événements');
    final groupTile = find.ancestor(
      of: find.text(groupName),
      matching: find.byType(InkWell),
    );
    await pumpUntil(tester, find.byWidgetPredicate((_) => true).first);
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (dashboard.evaluate().isEmpty && groupTile.evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) break;
      await tester.pump(const Duration(milliseconds: 200));
    }
    if (dashboard.evaluate().isEmpty) await tapAndPump(tester, groupTile);
    await pumpUntil(tester, dashboard);

    // ── Notes ─────────────────────────────────────────────────────────────
    await tapAndPump(tester, navTab('Notes'));
    await pumpUntil(tester, fab());
    await tapAndPump(tester, fab());
    await pumpUntil(tester, field('Titre'));
    await tester.enterText(field('Titre'), 'Note E2E');
    await save(tester);
    await pumpUntil(tester, find.text('Note E2E'));

    // ── Calendrier ────────────────────────────────────────────────────────
    await tapAndPump(tester, navTab('Calendar'));
    await pumpUntil(tester, fab());
    await tapAndPump(tester, fab());
    await pumpUntil(tester, field('Titre'));
    await tester.enterText(field('Titre'), 'Événement E2E');
    await save(tester);
    await pumpUntil(tester, find.text('Événement E2E'));

    // ── Dépenses ──────────────────────────────────────────────────────────
    await tapAndPump(tester, navTab('Expenses'));
    await pumpUntil(tester, fab());
    await tapAndPump(tester, fab());
    await pumpUntil(tester, field('Titre'));
    await tester.enterText(field('Titre'), 'Dépense E2E');
    await tester.enterText(field('Montant (€)'), '42.50');
    await save(tester);
    await pumpUntil(tester, find.text('Dépense E2E'));

    // ── Chat ──────────────────────────────────────────────────────────────
    await tapAndPump(tester, navTab('Chat'));
    final input = find.widgetWithText(TextField, 'Écrire un message...');
    await pumpUntil(tester, input);
    await tester.enterText(input, 'Bonjour E2E');
    await tester.pump(const Duration(milliseconds: 300));
    await tapAndPump(tester, find.byIcon(Icons.send));
    await pumpUntil(tester, find.text('Bonjour E2E'));

    // Les messages système des autres onglets sont arrivés dans le chat.
    await pumpUntil(tester, find.textContaining('Note E2E'));

    // ── Galerie paginée (requête média réelle, rules du dépôt) ────────────
    unawaited(GoRouter.of(tester.element(input)).push(AppRoutes.mediaGallery));
    await pumpUntil(tester, find.text('Aucun média partagé'));
    GoRouter.of(tester.element(find.text('Aucun média partagé'))).pop();
    // Le champ du chat reste dans l'arbre sous la galerie : attendre que
    // celle-ci ait disparu, sinon le tap suivant tombe dans la transition.
    await pumpUntilGone(tester, find.text('Aucun média partagé'));

    // ── Retour à l'accueil (dashboard) ────────────────────────────────────
    await tapAndPump(tester, navTab('Home'));
    await pumpUntil(tester, find.text('Événement E2E'));

    // ── Paramètres de l'accueil (sections espace / invitation / membres) ──
    unawaited(
      GoRouter.of(
        tester.element(find.text('Événement E2E').first),
      ).push(AppRoutes.settingsHome),
    );
    await pumpUntil(tester, find.text('Paramètres Accueil'));
    await pumpUntil(tester, find.text(groupName));
    await pumpUntil(tester, find.textContaining('Testeur'));
    final codeText = find.byWidgetPredicate(
      // Le code est affiché espacé (letterSpacing 4), contrairement aux
      // titres de section en capitales (« ESPACE »).
      (w) =>
          w is Text &&
          w.style?.letterSpacing == 4 &&
          RegExp(r'^[A-Z0-9]{6}$').hasMatch(w.data ?? ''),
    );
    await pumpUntil(tester, codeText);
    final inviteCode = (codeText.evaluate().first.widget as Text).data!;
    debugPrint('E2E code d\'invitation : $inviteCode');
    GoRouter.of(tester.element(find.text('Paramètres Accueil'))).pop();
    await pumpUntilGone(tester, find.text('Paramètres Accueil'));

    // ── Adhésion d'un 2e compte par code (callable joinGroupByCode, S3) ───
    unawaited(
      GoRouter.of(
        tester.element(find.text('Événement E2E').first),
      ).push(AppRoutes.profile),
    );
    await pumpUntil(tester, find.text('Se déconnecter'));
    await tapAndPump(tester, find.text('Se déconnecter'));
    await pumpUntil(tester, find.text('Déconnecter'));
    await tapAndPump(tester, find.text('Déconnecter'));

    await pumpUntil(tester, find.text('Continuer sans compte'));
    await tapAndPump(tester, find.text('Continuer sans compte').first);
    await pumpUntil(tester, field('Pseudo'));
    await tester.enterText(field('Pseudo'), 'Invité Deux');
    await tapAndPump(tester, find.widgetWithText(ElevatedButton, 'Continuer'));

    // Lien d'invitation : l'aperçu affiche le nom actuel de l'espace
    // (callable getInvitePreview), puis on rejoint (joinGroupByCode).
    await pumpUntil(tester, find.text('Rejoindre avec un code'));
    GoRouter.of(
      tester.element(find.text('Rejoindre avec un code')),
    ).go(AppRoutes.invite(inviteCode));
    await pumpUntil(tester, find.text('Tu as été invité·e à rejoindre'));
    await pumpUntil(tester, find.text(groupName));
    await tapAndPump(tester, find.widgetWithText(ElevatedButton, 'Rejoindre'));

    // L'espace rejoint s'ouvre, avec les données du premier compte…
    await pumpUntil(tester, find.text('Événement E2E'));
    // … et le message d'arrivée écrit par le serveur.
    await tapAndPump(tester, navTab('Chat'));
    await pumpUntil(
      tester,
      find.textContaining('Invité Deux a rejoint le groupe'),
    );
  });
}
