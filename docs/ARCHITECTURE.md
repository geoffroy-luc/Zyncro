# Architecture de Zyncro

> Pour un·e développeur·se qui découvre le projet. Historique et justification : [`docs/refactor/`](refactor/) (audit, plan, bugs connus).

Zyncro est une app Flutter de vie de groupe : calendrier, notes, dépenses et chat partagés au sein d'un « espace ». Toutes les données métier sont rattachées à un `groupId`.

- **Stack** : Flutter, Riverpod 3 (sans codegen), GoRouter, Firebase (Auth, Firestore, Storage, Messaging, App Check), Cloud Functions TypeScript (Node 22).
- **Dépôt** :
  - `zyncro/` : l'app ;
  - `functions/` : les Cloud Functions ;
  - `firestore.rules`, `storage.rules`, `firestore.indexes.json` ;
  - `firebase-tests/` : tests des rules ;
  - `hosting/` : liens d'invitation.

  Les déploiements se lancent **depuis la racine** du dépôt.

---

## 1. Couches et règles de dépendance

```
                ┌───────────────────────────────────────────┐
                │ app/  (composition root : router, shell,  │
                │        thème, listeners globaux)          │
                └───────────────┬───────────────────────────┘
                                │ connaît toutes les features
     ┌──────────────────────────┼───────────────────────────┐
     ▼                          ▼                           ▼
features/<f>/presentation ──► features/<f>/domain ◄── features/<f>/data
 (screens, widgets,            (entités pures,           (mappers Firestore,
  providers Riverpod)           interfaces de repo,       repositories Firebase,
     │                          services purs)            services techniques)
     ▼                              ▲                           │
design_system/ ──────────────► shared/domain ◄─────────────────┤
(tokens, thème)                (récurrence, catégories)        ▼
                                                     core/ (firebase, error,
                                                      logging, media, notifications,
                                                      app_update, utils)
```

Ces règles sont **vérifiées par des tests** (`zyncro/test/architecture/import_rules_test.dart`) :

| Règle | Pourquoi |
|---|---|
| `domain/` et `shared/domain/` sont du Dart pur : ni `package:flutter`, ni Firebase, ni Riverpod | Logique testable sans framework, indépendante du backend |
| Aucune instance `Firebase*.instance` en dehors de `core/firebase/` | Tout est injectable, donc testable (fakes, émulateurs) |
| `presentation/` n'importe ni `cloud_firestore` ni `firebase_storage` | L'UI ne parle jamais directement au backend |
| `core/` n'importe ni `features/` ni `app/` | Pas de cycles ; `core` est réutilisable |
| `shared/models/` n'existe plus | Les entités vivent dans le domaine de leur feature |

Une feature peut dépendre du contexte de session (`auth`, `groups`). Pour le reste, les features ne s'importent pas entre elles : elles passent par des ports de `shared/domain` ou par la composition dans `app/`.

## 2. Arborescence

```
zyncro/lib/
├─ main.dart                  bootstrap (Firebase, App Check, émulateurs en dev, tz, notifications)
├─ app/                       app.dart, router.dart (+ shell), notification_banner.dart
├─ core/
│  ├─ firebase/               firebase_providers (SEUL accès aux instances), firestore_paths
│  │                          (collections, ids, chemins Storage), firebase_emulators (dev)
│  ├─ error/                  Failure (sealed) + FailureMapper
│  ├─ logging/                AppLogger
│  ├─ media/                  ImagePickerService, FileStorage (+ implémentations, providers)
│  ├─ notifications/          PushNotificationService, PushTokenRepository, LocalNotifications,
│  │                          NotificationPreferences, providers
│  ├─ app_update/             AppUpdateService + AppUpdatePolicy (pure)
│  ├─ constants/, theme/      palette historique, ThemeData
│  └─ utils/                  color_hex, firestore_stream_extensions (mapDocsSafely)
├─ design_system/             tokens (ZyncroColors en ThemeExtension, AppSpacing, AppRadii),
│                             context_extensions (context.colors / context.textStyles)
├─ shared/
│  ├─ domain/                 recurrence (RecurrenceRule, advanceOccurrence), categories
│  ├─ data/mappers/           FirestoreCodec, mappers partagés
│  ├─ presentation/           extensions d'affichage (libellé de récurrence)
│  └─ widgets/                composants partagés (avatar, color picker, settings tiles…)
└─ features/
   ├─ auth/  groups/  dashboard/  calendar/  notes/  expenses/  chat/  settings/
   └─ <feature>/
      ├─ domain/              entities/, repositories/ (interfaces), services/ (purs)
      ├─ data/                mappers/ (XMapper + XFields), repositories/ (Firestore…), services/
      └─ presentation/        screens/, widgets/, providers/
```

## 3. Flux de données (exemple : notes)

```
Firestore ──snapshots()──► FirestoreNotesRepository (FirebaseFirestore injecté)
              │              └─ mapDocsSafely(docs, NoteMapper.fromFirestore)  ← doc illisible ignoré + loggé
              ▼
      notesProvider (StreamProvider, scopé par selectedGroupIdProvider)
              ▼
      NotesScreen / widgets  ── ref.watch(...) ──► rendu
Écriture : widget → notesRepositoryProvider.createNote(...) → NoteMapper.toFirestore(note) → set/update
```

- **Lecture** : `XMapper.fromFirestore(id, map)` convertit les `Timestamp` en `DateTime`. Les entités ne connaissent pas Firestore.
- **Écriture** : `XMapper.toFirestore(entity)`. Le format est **figé** par `test/characterization/models_wire_format_test.dart`.

## 4. Conventions

| Sujet | Convention |
|---|---|
| Entités | `features/<f>/domain/entities/`, Dart pur, champs `final`, `copyWith`. ⚠️ `copyWith` ne sait pas encore effacer un champ nullable (bugs K3 / CA1, voir `BUGS_FOUND.md`) |
| Mappers | `features/<f>/data/mappers/<x>_mapper.dart` : `abstract final class XMapper { fromFirestore, toFirestore }` + `abstract final class XFields` (noms de champs). Jamais de chaîne de champ en dur ailleurs |
| Chemins | `FirestoreCollections`, `FirestoreDocIds`, `StoragePaths` (`core/firebase/firestore_paths.dart`). Mêmes valeurs côté functions (`functions/src/shared/paths.ts`) |
| Repositories | Interface `XRepository` dans `domain/repositories/`, implémentation `FirestoreXRepository` dans `data/repositories/`, construite avec les instances de `firebase_providers`. Exposée par `xRepositoryProvider` (typé par l'interface) |
| Riverpod | Pas de codegen. `Provider` pour l'infrastructure, `StreamProvider` pour le temps réel, `Notifier`/`AsyncNotifier` pour les commandes et l'état. Pas d'effet de bord dans `build` ; `select` quand on ne lit qu'une partie d'un état |
| Erreurs | Les exceptions techniques sont traduites par `FailureMapper.from(e)` en `Failure` (sealed : PermissionDenied, NotFound, Network, Cancelled, Validation, Unknown). L'UI teste le type, jamais un code Firebase |
| Logs | `AppLogger.debug/info` (debug uniquement), `warning/error` (toujours). Jamais de token ni de donnée personnelle |
| Couleurs | `context.colors.<rôle>` (`ZyncroColors`, ThemeExtension). Aucune nouvelle couleur en dur dans un widget. Les valeurs claires sont celles de la palette historique (test `test/design_system`) |
| Imports | `package:zyncro/...` partout, triés (lint `always_use_package_imports`, `directives_ordering`) |
| Futures | `await`, ou `unawaited(...)` explicite (lints `unawaited_futures`, `discarded_futures`) |
| Analyse | `flutter analyze` à **0 issue**, infos comprises (`analysis_options.yaml` : strict-casts, strict-inference, strict-raw-types + règles) |

## 5. Contrat de données (rétro-compatibilité)

L'app est en production : les versions installées lisent et écrivent les mêmes documents. Règles :

1. **Ne jamais renommer** une collection, un champ ou une valeur d'enum stockée (`type` de message, `expenseType`, `splitType`, `role`…). Une nouvelle valeur d'enum fait ignorer le document par les anciennes versions (`mapDocsSafely`) : à éviter sans plan de migration.
2. Un nouveau champ doit être **optionnel**, avec un défaut à la lecture.
3. Sur un document existant, on écrit avec **`update()` ou `set(merge: true)`, jamais `set()` seul** : un `set()` sans merge effacerait les champs inconnus des anciennes versions.
4. Les réglages d'onglet s'écrivent **champ par champ** (`TabSettingsMapper.changedFields(from, to)`), jamais en carte complète.
5. Le schéma de référence est dans `docs/refactor/AUDIT.md` §2.4.

## 6. Sécurité

- **Rules** : `firestore.rules` et `storage.rules`.
  - L'appartenance à un groupe est vérifiée par l'existence de `groups/{gid}/members/{uid}`.
  - `createdBy` du groupe désigne le propriétaire.
  - Les rules Storage vérifient l'appartenance dans Firestore (rules cross-service).
- **Tests** : `firebase-tests/` (`npm install && npm test`, Java requis) rejoue tous les flux légitimes de l'app et une série d'attaques sur l'émulateur.
  - **Toute modification de rules commence par ces tests.**
- **Résiduel connu** : un non-membre qui connaît un `groupId` peut encore s'ajouter comme simple membre. La fermeture passe par une callable d'adhésion et une mise à jour forcée (`docs/refactor/PLAN.md`, S3).
- **App Check** : Play Integrity / DeviceCheck en release, providers debug en développement. L'enforcement n'est pas encore activé (S3).

## 7. Tests

| Type | Où | Commande |
|---|---|---|
| Unitaires (domaine, mappers, utils, policies) | `zyncro/test/**` | `cd zyncro && flutter test` |
| Caractérisation (comportement actuel figé, bugs compris : tests `BUG …`) | `zyncro/test/characterization/` | idem |
| Architecture (règles d'imports) | `zyncro/test/architecture/` | idem |
| Repositories (Firestore simulé) | `fake_cloud_firestore` | idem |
| Bout en bout (app réelle + émulateurs Firebase) | `zyncro/integration_test/app_smoke_test.dart` | émulateurs (`firebase emulators:start --only auth,firestore,storage --project zyncro-f5fdd`) puis `flutter test integration_test/app_smoke_test.dart --dart-define=USE_FIREBASE_EMULATORS=true -d <device>` |
| Rules | `firebase-tests/` | `cd firebase-tests && npm test` |
| Functions (triggers en snapshots + fonctions pures) | `functions/test/` | `cd functions && npm test` |

**Porte qualité** (CI `.github/workflows/ci.yml`) : format, analyse, tests, build APK debug, build / lint / test des functions, tests des rules.

Le branchement sur les émulateurs (`core/firebase/firebase_emulators.dart`) n'est actif qu'avec `--dart-define=USE_FIREBASE_EMULATORS=true`. C'est une constante de compilation, donc ce code est absent des builds de production.

## 8. Cloud Functions (`functions/src`)

- `index.ts` ne contient que des **ré-exports**. Les noms d'export sont l'identité des functions déployées : en renommer un les supprime puis les recrée.
- Un fichier par trigger, rangé par domaine : `groups/`, `messages/`, `expenses/`, `events/`, `notes/`.
- `shared/` : initialisation Admin, `guards` (lecture typée des documents clients), `members` (pseudo, tokens), `paths`.
- `notifications/` : envoi FCM (`fcm.ts`) et textes (fonctions pures).
- **Futur point unique pour les préférences de notification** : `getGroupTokens` / `getUsersTokens` dans `shared/members.ts`.

## 9. Marches à suivre

### Ajouter une feature

1. Créer `features/<f>/{domain,data,presentation}`.
2. **Domaine** : entités pures, interface `XRepository`, services purs avec leurs tests.
3. **Data** :
   - `XFields` + `XMapper` ;
   - un test de format comme ceux de `test/characterization/models_wire_format_test.dart` ;
   - `FirestoreXRepository` avec `FirebaseFirestore` injecté ;
   - lecture des listes via `mapDocsSafely`.
4. Ajouter la collection dans `FirestoreCollections`.
5. Écrire les rules, en commençant par les tests `firebase-tests/` (flux légitimes et attaques), puis les déployer depuis la racine.
6. **Presentation** :
   - providers Riverpod ;
   - écrans de composition (≤ 300 lignes) ;
   - widgets ;
   - couleurs via `context.colors`.
7. Route dans `app/router.dart`.
8. Couvrir le parcours dans le test bout en bout si c'est un parcours critique.

### Ajouter un réglage d'onglet

Les réglages vivent dans le document partagé `groups/{gid}/config/tabSettings`.

1. Ajouter le champ (nullable ou avec défaut) à `TabSettings` (`features/settings/domain/entities/`) et à son `copyWith`.
2. Dans `TabSettingsMapper` : une constante dans `TabSettingsFields`, la lecture avec un défaut, l'écriture dans `toFirestore`. Les anciennes versions ignorent le nouveau champ, et leur `set(merge: true)` ne l'efface pas.
3. Dans l'écran de réglages de l'onglet : lire `tabSettingsProvider`, écrire avec `updateSettings(groupId, from: settings, to: settings.copyWith(...))`. Seul le champ modifié est écrit.
4. Si le réglage est **personnel** (filtres, préférences d'affichage) et non partagé par le groupe : ne pas le mettre dans `tabSettings`, mais dans un document par utilisateur (voir `PLAN.md` §3).

### Ajouter une couleur ou une catégorie

- **Palette commune** : `customColors` et `hiddenBaseColors` de `TabSettings`. Composant : `ColorPickerRow` (`shared/widgets`).
- **Catégories** : `ExpenseCategory` (`shared/domain/categories`) et `ExpenseCategoryMapper`. Le système de catégories partagé entre calendrier, dépenses et notes y prendra place (`PLAN.md` §3).

### Ajouter une notification push

1. Écrire un trigger dans `functions/src/<domaine>/`.
2. Récupérer les destinataires via `getGroupTokens` / `getUsersTokens`, puis envoyer avec `sendGroupNotification(...)` (`screen` = onglet ouvert au tap).
3. Ajouter un test snapshot dans `functions/test/triggers.test.ts`.
4. Côté app, la navigation au tap est gérée par `app/app.dart` (`_onNotificationTap`).

### Modifier les rules

1. Ajouter le flux légitime **et** l'attaque dans `firebase-tests/tests/`.
2. Lancer `npm test`.
3. Modifier les rules.
4. Une fois vert, déployer depuis la racine : `firebase deploy --only firestore:rules,storage`.

## 10. Points d'extension prévus

Le tableau complet est dans `docs/refactor/PLAN.md` §3. Il couvre :
- réglages génériques par onglet, catégories et couleurs partagées ;
- rôles et permissions, recherche et filtres ;
- liens entre entités, service média ;
- mode sombre (fournir `ZyncroColors.dark`) ;
- sources d'événements externes ;
- préférences de notification ;
- bouton retour Android.
