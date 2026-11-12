# Plan de refactoring architectural — Zyncro

> Pré-requis de lecture : [`AUDIT.md`](AUDIT.md) (constats S-, A-, Y-, D-) et [`BUGS_FOUND.md`](BUGS_FOUND.md) (bugs K, C, M, E, CA, G, F, D).
> Statut : **validé** (D1–D10 acceptés) puis exécuté — avancement ci-dessous, détail dans [`RECAP.md`](RECAP.md).

## Avancement (2026-11-12)

| Étape | État |
|---|---|
| S1 rules | ✅ Firestore et Storage déployés, vérifiés (= dépôt) |
| S2 App Check client, logs, page d'invitation | ✅ fusionné dans `main` (local), à publier |
| S3 fermeture complète (mise à jour forcée) | 🟡 phase 1 faite (callable `joinGroupByCode` déployé, client release N, horodatage serveur K4) ; phases 2 et 3 : voir `S3.md` |
| Voie rapide G1, D1, D2 | ✅ |
| 0 Hygiène, CI | ✅ |
| 1 Lints stricts | ✅ 0 issue |
| 2 Filets (injection, caractérisation, bout en bout) | ✅ (bout en bout étendu : galerie, réglages de l'accueil) |
| 3 Fondations core | ✅ |
| 4 Domaine / data | ✅ |
| 5 Services transverses | ✅ (média : compression, galerie, enregistreur, sélecteur, aperçus de liens ; règle vérifiée par test) |
| 6 Design system | 🟡 tokens + palettes d'identité ; restent `Colors.white` (170), 35 littéraux, `TextStyle(` (263) |
| 7 l10n | 🟡 tous les `Text('…')` migrés (333 clés) ; ~120 chaînes hors `Text` |
| 8 Découpage des écrans | 🟡 max 514 lignes, `build` découpés en widgets et sections ; pas encore de controllers `Notifier` |
| 9 Navigation | ✅ (bouton retour : politique prête, non branchée) |
| 10 Performance | 🟡 non-lus, aperçu médias, galerie paginée (D9), frappe limitée, cache des aperçus de lien ; restent `cacheWidth`, cache disque, `autoDispose` |
| 11 Cloud Functions | ✅ découpées, Node 22, déployées |
| 12 Documentation | ✅ |
| 13 Corrections de bugs | 🟡 65 / 99 corrigés (`fix/bugs`) ; restants listés en tête de BUGS_FOUND |

## 1. Principes et garde-fous

1. **Comportement identique.** Chaque étape doit produire, pour l'utilisateur, exactement la même chose : écrans, textes, ordres de tri, messages système et notifications. Les bugs listés dans `BUGS_FOUND.md` sont **conservés**. Des tests de caractérisation nommés `bug_<ID>_…` les figent, puis seront inversés lors de l'étape 13.
2. **Schéma figé.** Le format Firestore et Storage décrit dans AUDIT §2.4 ne change pas. Concrètement :
   - mêmes chemins, mêmes noms de champs, mêmes types ;
   - mêmes omissions conditionnelles de clés ;
   - même usage de `set` et `update` ;
   - valeurs d'enum inchangées.

   Chaque mapper est verrouillé par des tests « golden map » : sur des fixtures, la carte produite par le nouveau code doit être identique à celle de l'ancien `toMap()`. Un nouveau champ ne peut être qu'**optionnel et additif**, ignoré par la v1.1.3, et seulement avec ton accord.
3. **Exports des Cloud Functions inchangés.** Un renommage provoque une suppression puis une recréation au déploiement, donc des notifications perdues pendant la fenêtre de bascule.
4. **Filets avant le scalpel.** Les tests de caractérisation de la logique pure et les goldens visuels des écrans sont posés **avant** de déplacer le code correspondant.
5. **Une étape = un ou plusieurs commits `[REFACTO]` atomiques**, sur `refactor/architecture`. Chaque commit doit passer la porte qualité (§6.1). Un déplacement pur de code et un changement de logique ne cohabitent jamais dans le même commit.
6. **Sécurité traitée à part.** Les correctifs S1 à S3 suivent leur propre branche et leur propre calendrier. Ce ne sont pas du refactor : ils changent le comportement du serveur face à des clients malveillants, jamais face à la v1.1.3 légitime (prouvé par les tests).

---

## 2. Architecture cible

### 2.1 Arborescence

```
zyncro/lib/
├─ main.dart                         ≤ 15 lignes : runApp(bootstrap())
├─ bootstrap/bootstrap.dart          init ordonnée et testable (Firebase, App Check, tz, notifications)
├─ app/                              COMPOSITION ROOT : seul endroit qui connaît toutes les features
│  ├─ app.dart                       MaterialApp.router, thème, l10n, listeners globaux
│  ├─ registries.dart                assemblage des registres (sections de réglages, résolveurs de liens, filtres)
│  └─ router/
│     ├─ app_router.dart             GoRouter
│     ├─ routes.dart                 chemins et noms en constantes (AppRoutes.calendar…)
│     ├─ redirect_policy.dart        logique de redirection PURE (testée)
│     ├─ app_shell.dart              StatefulShellRoute : top bar + bottom nav
│     └─ back_navigation_policy.dart point d'extension du retour Android (non implémenté)
├─ core/                             transverse, sans dépendance vers les features
│  ├─ error/                         failure.dart (sealed), failure_mapper.dart, failure_messages.dart
│  ├─ logging/app_logger.dart
│  ├─ firebase/                      firebase_providers.dart (Firestore, Storage, Auth, Messaging : overridables),
│  │                                 firestore_paths.dart, fields/*.dart, timestamp_codec.dart, stream_errors.dart
│  ├─ media/                         media_service.dart (port), media_policy.dart, storage_paths.dart,
│  │                                 firebase_media_service.dart, image_compressor.dart, media_cache.dart
│  ├─ notifications/                 push_service.dart, notification_tap_router.dart, local_notifications.dart
│  ├─ deep_links/                    invite_link.dart, deep_link_service.dart
│  ├─ share/                         share_intake_service.dart, share_shortcuts_channel.dart
│  ├─ navigation/app_navigator.dart  port de navigation (casse les cycles feature ↔ router)
│  ├─ query/                         query.dart, filter.dart, text_matcher.dart (recherche et filtres réutilisables)
│  ├─ preferences/local_store.dart   wrapper SharedPreferences injecté
│  └─ utils/                         color_hex.dart, formatters/{money,date,duration,relative_time}.dart
├─ design_system/
│  ├─ tokens/                        app_palette.dart (valeurs brutes), zyncro_colors.dart (ThemeExtension sémantique),
│  │                                 spacing.dart, radii.dart, typography.dart, shadows.dart, durations.dart
│  ├─ theme/app_theme.dart           light() ; dark() prévu mais non branché
│  ├─ context_extensions.dart        context.colors / context.text / context.l10n
│  └─ components/                    app_card, icon_badge, group_avatar, user_avatar, confirm_dialog,
│                                    app_snackbar, loading_button, section_header, sheet_scaffold,
│                                    gradient_circle_button, search_bar, color_palette_row, empty_state…
├─ l10n/app_fr.arb                   (+ code généré par gen-l10n)
├─ shared/domain/                    Dart pur, partagé entre features
│  ├─ recurrence/                    recurrence_rule.dart, recurrence_expander.dart
│  ├─ time/date_range.dart
│  ├─ money/money.dart               (introduit à l'étape 13 seulement, voir E1/E2)
│  ├─ links/entity_ref.dart          références entre features
│  ├─ activity/activity_log.dart     port « journal d'activité » (messages système)
│  └─ categories/                    category.dart, palette.dart (couleurs et catégories partagées)
└─ features/<feature>/
   ├─ <feature>.dart                 barrel = API PUBLIQUE de la feature (seul fichier importable ailleurs)
   ├─ domain/                        Dart pur : entities/, repositories/ (interfaces), services/, policies/
   ├─ data/                          dtos/, mappers/, repositories/ (implémentations), sources/, <feature>_data_providers.dart
   └─ presentation/                  screens/ (≤ ~150-300 l., composition), widgets/,
                                     controllers/ (Notifier, AsyncNotifier : commandes et état UI),
                                     providers/ (read models dérivés)
```

Features cibles :
- `auth`, `groups` (contexte de groupe, membres, rôles, invitations) ;
- `dashboard`, `calendar`, `notes`, `expenses`, `chat` ;
- `media` (viewer, galerie, picker), `share` (partage entrant) ;
- `settings` (système générique de réglages d'onglet), `categories`.

### 2.2 Couches et règles de dépendance

```
presentation ──► domain ◄── data          app/ ──► toutes les features (composition root)
     │              ▲          │          features ──► core, design_system, shared/domain
     ▼              │          ▼          features ──► API publique de `auth` et `groups` uniquement
design_system   shared/domain  core/firebase
```

| Règle | Vérifiée par |
|---|---|
| `domain/` et `shared/domain/` n'importent ni `package:flutter`, ni `firebase_*`, ni `cloud_firestore`, ni `flutter_riverpod` | `test/architecture/import_rules_test.dart` (scan des imports) |
| Une feature n'importe une autre feature que via son barrel, et seulement `auth` ou `groups` (contexte). Toute autre interaction passe par un port de `shared/domain` (`ActivityLog`, `EntityRef`, résolveurs) | idem |
| `core/` n'importe jamais `features/` ni `app/` | idem |
| Aucun `FirebaseFirestore.instance`, `FirebaseStorage.instance`, etc. hors `core/firebase/firebase_providers.dart` | idem (grep) |
| Pas de `Color(0x`, `Colors.` (sauf `transparent`) ni `TextStyle(` hors `design_system/` | idem (grep) |
| Pas de chaîne affichée en dur dans `presentation/` | revue + test (Text/SnackBar avec littéral) |

### 2.3 Conventions

| Sujet | Convention |
|---|---|
| Nommage | Interfaces de domaine : `EventsRepository`. Implémentations : `FirestoreEventsRepository`. Le préfixe `I` actuel est abandonné. Fichiers en snake_case, un type public par fichier |
| Entités | `final class`, champs `final`, constructeur `const`, `==`/`hashCode` (`Object.hash`), `copyWith` capable d'effacer un champ nullable (sentinelle `Nullable<T>`). Valeurs fermées : `enum` ou `sealed class` (`MessageContent` : Text, Media, Album, Audio, Poll, System). **Aucun codegen** (ni freezed, ni json_serializable) : moins d'outillage et des mappers explicites, donc testables |
| DTO et mappers | `XxxDto.fromFirestore(Map)` et `toFirestore()` reproduisent le format exact actuel. `XxxMapper` convertit entre DTO et entité. Écritures séparées : `toCreateMap()` et `toUpdateMap()`. Noms de champs dans `core/firebase/fields/` (`EventFields.startDate`), chemins dans `FirestorePaths` (`FirestorePaths.groupEvents(gid)`) |
| Repositories | Reçoivent `FirebaseFirestore` et `FirebaseStorage` par constructeur ; exposés via `xxxRepositoryProvider` typé par l'interface de domaine ; lèvent des `Failure`, jamais des `FirebaseException` |
| Services de domaine | Fonctions ou classes pures, sans état ni I/O : `BalanceCalculator`, `SettlementPlanner`, `SplitCalculator`, `RecurrenceExpander`, `CalendarDayIndex`, `PollTally`, `MessageGrouping`, `MessagePermissions`, `GroupPermissions`, `DashboardSummary`… Ce sont les cibles prioritaires des tests unitaires |
| Use cases | Seulement quand ils orchestrent plusieurs ports, par exemple `SaveExpense` = repository + `ActivityLog` (message système). Pas de use case « passe-plat » |
| Imports | `package:zyncro/…` partout (`always_use_package_imports`), triés |
| Fichiers | Plafond indicatif de 300 lignes ; écran ≤ 150 lignes visé. Au-delà, extraire widgets ou controller |

### 2.4 Gestion d'état (Riverpod 3, sans codegen)

| Besoin | Outil | Durée de vie |
|---|---|---|
| Instance d'infrastructure (Firestore, repositories, services) | `Provider` | app |
| Contexte de session : utilisateur, groupe sélectionné, membre courant, membres du groupe | `StreamProvider` / `AsyncNotifier` dans `auth` et `groups` | app, un **seul** stream `watchMembers` (aujourd'hui ×4) |
| Données temps réel d'une feature, scopées au groupe | `StreamProvider` (keepAlive, recréé au changement de groupe) | branche du shell |
| Données dérivées (soldes, occurrences du mois, résumé du dashboard) | `Provider` qui appelle un service de domaine pur ; les widgets watchent via `select` | idem |
| Commandes et état d'un formulaire ou d'un écran | `Notifier` / `AsyncNotifier` (controller) ; état immuable ; commandes `Future<void>` ; soumission en `AsyncValue` | `autoDispose` |
| État éphémère de widget (animation, focus, scroll) | `State` local | widget |

Règles :
- **Aucune logique métier dans un widget ni dans `build`.**
- **Aucun effet de bord dans `build`.** Utiliser `ref.listen` ou `listenManual`, et `addPostFrameCallback` uniquement dans `initState`.
- **`select` systématique** quand un widget n'utilise qu'une partie d'un état.

### 2.5 Gestion d'erreurs et logging

- `core/error/failure.dart` :

  ```dart
  sealed class Failure {
    PermissionDenied, NotFound, Network, Cancelled, Conflict,
    Validation(field, code), StorageQuota, Unknown(cause, stack)
  }
  ```

  `FailureMapper.from(Object e)` traduit `FirebaseException`, `FirebaseAuthException`, `SocketException`, `PlatformException`, etc.
- **Pas de type `Result`** : Riverpod porte déjà l'erreur dans `AsyncValue`. Les repositories lèvent des `Failure`, les streams passent par `.mapFailures()`, et les controllers utilisent `AsyncValue.guard`. Un `Result` ajouterait de la cérémonie sans gain réel.
- UI : un helper `ref.listenFailures(controllerProvider, context)` affiche `AppSnackbar.failure(...)`. Les textes viennent de `failure_messages.dart` (l10n).

  **Pendant le refactor, chaque écran garde ses textes d'erreur actuels**, même incohérents (par exemple « Permission refusée » pour toute erreur dans EVF et EXF : bugs E24 et CA6). L'harmonisation se fera à l'étape 13.
- `AppLogger` (tag, niveau, erreur, stack) écrit vers `dart:developer` et `debugPrint` en debug. Il est conçu pour accueillir plus tard un sink Crashlytics, sans dépendance aujourd'hui. On n'y logge jamais de token ni de donnée personnelle (le token FCM est actuellement loggé, NOTIF:80).
- Plus de `catch (_) {}` silencieux. Soit on mappe et on remonte l'erreur, soit on la logge avec la justification en commentaire. Les lints `avoid_catches_without_on_clauses` et `empty_catches` l'imposent.

### 2.6 Cloud Functions (cible)

```
functions/src/
├─ index.ts                     ré-exports UNIQUEMENT (mêmes noms d'export qu'aujourd'hui)
├─ shared/  firebase.ts (admin init), logger.ts, paths.ts, guards.ts (parsing typé des documents), types.ts
├─ notifications/  fcm.ts (envoi multicast + nettoyage des tokens [étape 13]), recipients.ts (POINT UNIQUE :
│                  membres → tokens, futur filtrage par préférences), payloads.ts (textes purs, testés)
├─ groups/   onGroupDeleted.ts, onMemberRemoved.ts
├─ messages/ onNewMessage.ts, onMessageReaction.ts
├─ expenses/ onNewExpense.ts, onExpenseUpdated.ts
├─ events/   onEventCreated.ts, onEventUpdated.ts, onEventDeleted.ts
├─ notes/    onNoteCreated.ts, onNoteUpdated.ts, onNoteDeleted.ts
└─ invites/  (S3) joinGroupByCode.ts : callable, App Check, limitation de débit
```

Outillage : ESLint + `typescript-eslint` (strict), `vitest` pour les fonctions pures (payloads, recipients, guards), `predeploy` build + lint dans `firebase.json`.

---

## 3. Points d'extension pour les features à venir

Aucune de ces features n'est implémentée. Voici ce qui les rend simples à ajouter.

| Feature à venir | Point d'extension | Où |
|---|---|---|
| **Réglages par onglet** (chat : couleur, galerie, fond ; dépenses : couleur, catégories, devise ; notes : couleurs ; calendrier : couleurs, bande ou point, catégories, filtres ; home : couleurs, bannière, photo, emoji) | Feature `settings` générique : `TabId` (enum) ; un objet de valeur par onglet (`CalendarTabSettings`…) sur un `TabAppearance` commun ; un **registre** `Map<TabId, List<SettingsSectionSpec>>` assemblé dans `app/registries.dart`, chaque feature fournissant ses sections ; `TabSettingsScreen(tab)` unique (routes `/settings/<tab>` inchangées) ; sections réutilisables `ThemeColorSetting`, `PaletteSetting`, `PhotoSetting`, `EmojiSetting`, `EnumChoiceSetting`, `CategoriesSetting`, `CurrencySetting`. **Ajouter un réglage = 1 champ dans l'objet de valeur + 1 clé optionnelle dans le DTO + 1 `SectionSpec`.** Les anciennes versions ignorent les clés inconnues, et leur écriture `set(merge: true)` ne les efface pas | `features/settings/`, `app/registries.dart` |
| **Catégories et couleurs partagées** (calendrier, dépenses, notes) | `shared/domain/categories/` : `Category {id, name, iconKey, colorHex}`, `CategoryScope {expenses, calendar, notes}`, `Palette {base, custom, hidden}`. `CategoryRepository` lit les champs legacy (`expensesCategories`, `expensesCustomCategories`, `calendarCustomCategories`) avec `id = slug(name)` ; les dépenses gardent `category` = nom pour la v1.1.3. Composants partagés `CategoryPicker`, `CategoryEditorSheet`, `ColorPaletteRow`. Palettes **par scope** possibles sans casser le format actuel (champ optionnel) | `shared/domain/categories`, `features/categories` |
| **Rôles admin / propriétaire et permissions** | Domaine : `GroupRole {owner, admin, member, unknown}` (une valeur inconnue est traitée comme `member`) et `GroupPermissions.can(role, GroupAction)` (table pure testée). Provider `can(GroupAction)` pour l'UI. Source de vérité unique : `members/{uid}.role`, `createdBy` restant synchronisé pour la v1.1.3. Rules : fonctions `memberRole(gid)`, `hasRole(gid, [...])` introduites en S1. « Le propriétaire supprime les messages des autres » se résume alors à 1 ligne dans la table, 1 condition dans `allow delete`, et l'action ajoutée au menu du message | `features/groups/domain/policies`, `firestore.rules` |
| **Recherche et filtres sur chaque onglet** | `core/query/` : `Query<T> {text, filters, sort}`, `Filter<T>.matches`, `TextMatcher` (même sémantique qu'aujourd'hui : `toLowerCase().contains`). Un `TabQueryController` (family `TabId`) par onglet et un composant `AppSearchBar`. Filtres de domaine `EventFilter` (participant, lieu, récurrence, catégorie), `ExpenseFilter`, `NoteFilter`, `MessageFilter`. Les recherches actuelles (chat, notes, dépenses, calendrier) y migrent à l'identique | `core/query`, `features/*/domain/services/*_filter.dart` |
| **Lier une note ou une dépense à un événement** | `shared/domain/links/EntityRef {EntityType, id}` + `LinkedEntityResolver` enregistré par chaque feature dans `app/registries.dart` (EntityRef → aperçu : titre, icône, route). Aucune feature n'importe l'autre. Stockage futur : champ optionnel `links: [{type, id}]`. Compatible, car toutes les mises à jour existantes passent par `update()`, qui conserve les champs inconnus ; règle documentée : **jamais de `set()` sans merge sur un document existant**. Pré-requis : des ids d'occurrence stables (E11, `seriesId + occurrenceStart`) | `shared/domain/links`, `app/registries.dart` |
| **Photo de profil du groupe, « télécharger toutes les photos », envoi via « Partager »** | `core/media/MediaService` : `prepare(local, MediaPolicy)` (profils de compression actuels : chat q85/1920/sans EXIF, fond q80/1080, avatar q85/512), `upload` / `uploadBatch` (concurrence bornée, progression), `download` (cache disque), `saveToGallery` / `saveAll`, `cleanupTemp`. `StoragePaths` centralise les chemins. `ShareIntakeService` normalise les partages entrants. iOS demandera une Share Extension (hors refactor, AUDIT A-18) | `core/media`, `core/share`, `features/media`, `features/share` |
| **Date des messages, menu « … » sur les messages** | `MessageGrouping` (déjà nécessaire pour l'extraction) expose les séparateurs de date. `MessageActionsSheet` est piloté par l'enum `MessageAction` et `MessagePermissions`. Le menu « … » réutilise la même liste d'actions | `features/chat/domain/services`, `presentation/widgets/message_actions_sheet.dart` |
| **Mode sombre** | Toutes les couleurs passent par `context.colors` (ThemeExtension `ZyncroColors`). Les valeurs claires = les valeurs actuelles exactes. `AppTheme.dark()` n'attend plus qu'une palette sombre et un `themeModeProvider` | `design_system/` |
| **Import et synchro d'un calendrier externe (Google)** | `calendar/domain/sources/EventSource {id, isWritable, watch(groupId, DateRange)}`. `FirestoreEventSource` aujourd'hui, `GoogleCalendarEventSource` demain. `combinedEventsProvider` fusionne les sources avant le `RecurrenceExpander`. Les occurrences portent `sourceId`, et une source non éditable désactive l'édition | `features/calendar/domain/sources`, `data/sources` |
| **Préférences de notifications par utilisateur, groupe et type** | Côté functions, **point unique** `notifications/recipients.ts` : `resolveRecipients(groupId, type, excludeUid)`. Il suffira d'y lire `users/{uid}/notificationPrefs/{groupId}` (nouveau document, sans impact sur la v1.1.3). Côté app : `NotificationPreferencesRepository` + une section de réglages via le registre | `functions/src/notifications`, `features/settings` |
| **Bouton retour Android** | `app/router/back_navigation_policy.dart` : fonction pure `(onglet courant, branche dépilable, stack racine) → action` (dépiler la branche, revenir à l'onglet Accueil, aller à `/groups`), testée. Elle sera branchée via un `PopScope` dans `app_shell.dart`. Navigation centralisée dans `AppNavigator` | `app/router` |

---

## 4. Plan d'exécution par étapes

Légende risque : 🟢 faible · 🟡 moyen · 🔴 élevé. La porte qualité est définie en §6.1. La checklist manuelle (« smoke ») est en annexe A.

### Voie sécurité (branche `fix/security-rules`, partie de `main`, indépendante du refactor)

#### S1. Durcissement des rules, rétro-compatible avec la v1.1.3 · 🟡

Objectif : bloquer S-02, S-03, S-04, S-05 et réduire S-01, **sans modifier le client**.

Contenu :

**`invite_codes`**
- `get` autorisé, **`list` interdit** (la v1.1.3 ne fait que des `get` : GR:108, 244).
- `create` : réservé à un membre du groupe visé (`existsAfter` sur le doc membre, pour couvrir le batch de `createGroup`), avec des clés limitées à `groupId`, `groupName`, `groupEmoji`.
- `delete` : réservé à un membre du groupe visé.

**`groups` update**
- `createdBy` n'est modifiable que par le propriétaire actuel, et vers un membre (transfert).
- `memberIds` :
  - un membre ne peut retirer que lui-même ;
  - le propriétaire peut retirer n'importe qui ;
  - le chemin « non-membre » est limité à l'**ajout de soi uniquement**, et seul le champ `memberIds` peut changer.
- Les autres champs restent ouverts aux membres : la régénération du code n'est pas réservée au propriétaire dans l'UI (HS:648).

**`members`**
- `create` : `uid ∈ getAfter(group).memberIds`, avec `role == 'member'`, ou `'owner'` seulement si `createdBy == uid`.
- `update` : soi-même, sans auto-promotion (le rôle ne peut que passer à `member`) ; ou le propriétaire, sur n'importe quel membre.
- `delete` : soi-même sauf le propriétaire, ou le propriétaire sur un autre membre.

**`messages`**
- `create` : `senderId == auth.uid`.
- `update` : l'expéditeur, sur les champs `content`, `editedAt` et `reactions` uniquement ; tout membre, sur `reactions` uniquement (réactions et votes).
- `delete` : l'expéditeur.

**`expenses`, `events`, `notes`**
- `create` : `groupId == {gid}` et `createdBy == auth.uid`.
- `update` : `createdBy` inchangé.
- Contrôle de type minimal sur les champs que `fromMap` caste strictement. C'est une mitigation de D1 : un document malformé ne peut plus être écrit par un client.

**Storage**
- `media/{gid}` et `audio/{gid}` : lecture, listage et création réservés aux **membres** (`firestore.exists(...members/uid)`, rules cross-service).
- `group_photos` et `chat_backgrounds` : écriture et suppression réservées aux membres du groupe désigné par le nom du fichier. La lecture reste ouverte à tout utilisateur connecté, car l'aperçu d'invitation lit la photo **avant** l'adhésion (GR:257).
- `profile_photos` : `image/*` et < 5 Mo.

**Suite de tests** `firebase-tests/` (Node, `@firebase/rules-unit-testing`, `vitest`)
- **Tous les flux légitimes de la v1.1.3** reproduits à l'identique (mêmes batches, mêmes champs) :
  - créer un groupe, rejoindre par code, rejoindre à nouveau, quitter ;
  - retirer un membre, transférer la propriété, supprimer le groupe, régénérer le code ;
  - modifier le pseudo, propager la photo, `markAsRead` ;
  - typing, et toutes les écritures de messages : texte, système, audio, média, album, sondage, édition, vote, réaction, suppression ;
  - CRUD des dépenses, remboursements, événements et notes ;
  - `tabSettings` ;
  - uploads Storage.
- Les **12 attaques** de l'AUDIT §10.6.

Ce qui **reste ouvert** jusqu'à S3 : un non-membre qui connaît un `groupId` peut encore s'ajouter, sans pouvoir prendre le contrôle du groupe. Avec `list` fermé, un `groupId` ne fuit plus que via une URL de média ou un ancien membre.

- Risque : 🟡. Une rule trop stricte casserait un flux de prod. La matrice des flux légitimes est la protection : chaque flux est d'abord écrit contre les rules **actuelles** (vert), puis rejoué contre les nouvelles.
- Vérification :
  - `firebase-tests` vert (flux légitimes autorisés, attaques refusées) ;
  - déploiement depuis la racine (`firebase deploy --only firestore:rules,storage`) **après ton accord** ;
  - smoke test complet sur un téléphone en v1.1.3 de production (annexe A, sections G, CH, M, E, CA, N) ;
  - surveillance des `permission-denied` dans les logs pendant 48 h ;
  - rollback = redéploiement des rules précédentes (versionnées).
- Note : les rules cross-service Storage → Firestore demandent d'accorder un rôle IAM au compte de service Storage (proposé par la console au premier déploiement).

#### S2. App Check fonctionnel côté client · 🟢 (release applicative)

Contenu :
- `providerAndroid: kReleaseMode ? AndroidPlayIntegrityProvider() : AndroidDebugProvider()`, `providerApple: AppleAppAttestWithDeviceCheckFallbackProvider()`.
- Suppression du log du token FCM.
- `invite.html` : validation `^[A-Z0-9]{6}$` et vraie URL App Store (id à fournir).
- `assetlinks.json` : empreinte Play App Signing (à fournir).

Ce qui reste hors périmètre : **pas d'enforcement**. Il viendra en S3, une fois les anciennes versions retirées : celles-ci envoient des tokens debug et seraient rejetées.

Vérification :
- métriques App Check dans la console (proportion de requêtes vérifiées) ;
- build release Android et iOS testé.

#### S3. Fermeture complète · 🔴 (nécessite une **mise à jour forcée** via `config/app_version.minimum_version`, décision séparée)

Contenu :
- Callable `joinGroupByCode` : Admin SDK, App Check requis, limitation de débit par uid, message système d'adhésion écrit côté serveur.
- Puis rules : suppression du chemin d'auto-ajout et du `members.create` client.
- Timestamps serveur pour les messages (corrige K4), rule `timestamp == request.time`, lecture `ServerTimestampBehavior.estimate`.
- Enforcement App Check (Firestore, Storage, Functions).
- Optionnel : tokens d'invitation longs (≥ 128 bits) pour les liens, en gardant le code à 6 caractères pour la saisie manuelle ; tokens FCM multi-appareils.

Séquence :
1. release N (nouveau client compatible avec les anciennes et les nouvelles rules) ;
2. adoption suffisante ;
3. hausse de `minimum_version` ;
4. rules strictes et enforcement.

### Voie refactor (branche `refactor/architecture`)

| # | Étape | Contenu | Risque | Vérification |
|---|---|---|---|---|
| **0** | Hygiène et outillage | `git rm --cached` sur `functions/node_modules` et `functions/lib`, mise à jour du `.gitignore`. Workflow de PR : format, analyze, test, build apk debug, build et lint des functions, tests des rules. Flutter épinglé (`3.41.5`) dans les workflows de déploiement. `firebase.json` : `predeploy` functions + `firestore.indexes.json` (vide = l'état de prod). Commit des docs | 🟢 | CI verte ; `firebase deploy --only firestore:indexes --dry-run` |
| **1** | Lints durcis | `analysis_options.yaml` : `strict-casts`, `strict-inference`, `strict-raw-types` + environ 40 règles (`always_use_package_imports`, `prefer_const_*`, `unawaited_futures`, `discarded_futures`, `cancel_subscriptions`, `close_sinks`, `avoid_dynamic_calls`, `avoid_catches_without_on_clauses`, `use_build_context_synchronously`, `require_trailing_commas`, `directives_ordering`…). Corrections en 3 commits : (a) `dart fix --apply` mécanique, (b) casts et inférence explicites, (c) futures : **seulement** `unawaited(...)` explicite, jamais d'`await` ajouté, donc sémantique inchangée. Les `RadioGroup` dépréciés sont migrés à l'identique | 🟢 | `flutter analyze` = **0 issue** ; build ; smoke rapide |
| **2** | Filets de sécurité | (a) **Injection Firebase** : `core/firebase/firebase_providers.dart`, repositories construits avec `FirebaseFirestore`/`Storage` injectés (valeur par défaut inchangée). (b) **Tests de caractérisation** de la logique existante telle quelle, bugs compris : `expandEvents`/`expandExpenses` (RU), `balancesProvider`, `_computeSettlements`, `_buildSplitAmounts`, `TabSettings.fromMap` legacy, `fromMap`/`toMap` aller-retour de chaque modèle (fixtures = documents réels anonymisés + cas legacy), `InviteLink.codeFromUri`, `UpdateService._compare`, score d'activité, `orderedGroupsProvider`, redirect du router | 🟢 | Les tests passent sur le code **non modifié** ; couverture des fichiers ciblés ≥ 90 % |
| **3** | Fondations core | `Failure`, `FailureMapper`, `AppLogger`, `FirestorePaths` + constantes de champs, `ColorHex` (`tryParse`, `darken` = HSL −0,12 à l'identique), formatters (montant, date, durée, temps relatif : **deux variantes conservées**, DB et NS, Y-04), `LocalStore`. Remplacement des duplications **là où la sortie est prouvée identique** par test | 🟢 | Tests unitaires des utilitaires ; tests de caractérisation toujours verts |
| **4** | Domaine et data, une feature par commit | Ordre : notes → calendar → expenses → groups (+ members, invites) → chat (messages, `MessageContent`, codec JSON) → auth/user → settings (tabSettings, lu et écrit à l'identique). Pour chaque feature : entités pures, interface de repository, DTO + mapper, implémentation Firestore injectée, providers. `shared/models` se vide progressivement (re-export temporaire pour garder des commits petits, supprimé en fin d'étape). `IAuthRepository` cesse d'exposer `firebase_auth.User` (entité `AppUser` du domaine). Port `ActivityLog` implémenté par chat/data, **avec les mêmes textes** de messages système | 🟡 sérialisation | **Golden map tests** (nouveau `toFirestore` == ancien `toMap` sur fixtures, `fromFirestore` équivalent) ; tests de repositories avec `fake_cloud_firestore` (chemins, `orderBy`, `limit`, `set` vs `update`) ; test d'architecture : `domain/` pur ; smoke CRUD de chaque onglet |
| **5** | Services transverses | `MediaService` (absorbe les 3 compressions et les 6 uploads, mêmes paramètres et mêmes chemins) ; `PushService` instanciable (plus de `WidgetRef` statique) + `NotificationTapRouter` ; `AppNavigator` (port) qui **casse les cycles** feature ↔ router ; `ReminderScheduler` (port) + implémentation locale ; `ShareIntakeService` ; `DeepLinkService` ; `UpdateService` injectable | 🟡 | Tests unitaires avec fakes ; smoke sur appareil : tap sur notification (à froid et à chaud), partage Android (simple, multiple, Direct Share), lien d'invitation (à froid, à chaud, déconnecté), envoi photo, vidéo, album, audio, rappel d'événement |
| **6** | Design system | **D'abord** : goldens de référence des écrans clés, rendus avec des fakes (rendus possibles grâce aux étapes 2 et 4). **Ensuite** : tokens (valeurs actuelles exactes : `0xFFF7F9FC` → `colors.background`, etc.), ThemeExtension `ZyncroColors`, spacing, radii, typo, ombres, `context.colors` ; composants partagés (AppCard, IconBadge, GroupAvatar, ConfirmDialog, AppSnackbar, LoadingButton, SectionHeader, SheetScaffold, GradientCircleButton, ColorPaletteRow…) | 🟡 visuel | Goldens inchangés (au pixel près ; tolérance à documenter si l'anticrénelage diffère) |
| **7** | Infrastructure l10n | `generate: true`, `l10n.yaml`, `app_fr.arb` (template FR), extension `context.l10n`. Les clés sont créées au fil de l'étape 8, **chaînes identiques au caractère près** | 🟢 | Build ; test qui vérifie que chaque clé ARB est utilisée |
| **8** | Découpage des écrans | Une feature à la fois, 3 commits minimum par écran : (a) extraction de widgets (**déplacement pur**), (b) logique → services de domaine + controllers (avec tests), (c) tokens + l10n. Ordre (du plus simple au plus risqué) : notes → calendar → expenses → dashboard → groups (factorisation HS ; suppression de GSET et de la route `/group-settings`, code mort, sous réserve D7) → auth/profile → media (viewer, galerie, picker) + share → **chat** en 6 sous-étapes (sondages, audio, médias et bulles, réactions et réponse, composer, liste et pagination). Réglages : migration des 5 écrans vers `TabSettingsScreen` + registre, **rendu identique** | 🟡 → 🔴 pour le chat | Goldens par écran ; widget tests des parcours critiques (connexion, sélection de groupe, création de dépense, de remboursement, d'événement et de note, envoi d'un message, d'une réaction, d'un vote) ; tous les fichiers ≤ 300 lignes (test d'architecture) ; smoke de la feature |
| **9** | Navigation | Découpage de `router.dart` (routes, redirect pur, shell). Effet de bord du shell retiré du `build`. Constantes de routes. Les `MaterialPageRoute` impératifs sont **conservés** (les passer en GoRoute changerait la pile, donc le comportement du retour : à faire avec la feature « bouton retour ») mais centralisés dans `AppNavigator`. `back_navigation_policy.dart` créé, testé, **non branché** | 🟡 | Tests du `redirect_policy` ; smoke de navigation complet |
| **10** | Performance (visuel identique) | `select` partout ; `const` ; `autoDispose` des controllers ; un seul stream de membres ; non-lus bornés `limit(100)` (« 99+ » déjà affiché au-delà de 99, rendu identique) ; aperçu média du dashboard en `orderBy` + `limit(6)` + index composite `(type, timestamp desc)` déclaré et déployé ; galerie paginée (D9) ; `cacheWidth`/`cacheHeight` des miniatures ; cache disque (D4) ; cache des aperçus de lien ; throttle de `setTyping` (indicateur identique : seuil de 6 s) ; `jsonDecode` sorti du `build` ; rebuilds localisés du composer et du chrono d'enregistrement | 🟡 | Mesures DevTools avant/après (rebuilds, lectures Firestore sur un scénario type) ; goldens ; index déployé **avant** le client qui l'utilise |
| **11** | Cloud Functions | Découpage par domaine (§2.6), helpers partagés, parsing typé des documents, `logger`, ESLint strict, tests `vitest` des payloads et des destinataires. **Exports et textes de notification identiques**, bugs F1–F4 et G7/G8 conservés. Node 22 + mise à jour des SDK selon D8 | 🟡 | `npm run build`, `lint`, `test` ; émulateur Functions + Firestore : chaque trigger produit le même payload qu'avant (tests de caractérisation écrits **avant** le découpage) ; déploiement depuis la racine après accord |
| **12** | Documentation | `docs/ARCHITECTURE.md` (schéma des couches, conventions, « ajouter une feature », « ajouter un réglage d'onglet », « ajouter une catégorie ou une couleur », « ajouter une rule ») ; `zyncro/AGENTS.md` mis à jour ; récapitulatif final (changements, dette assumée, recommandations) | 🟢 | Relecture |
| **13** | Corrections de bugs (post-refactor, chacune validée par toi) | Priorités proposées : D1 (parsing tolérant), G1 (écriture champ par champ des réglages), K2/E8/E9 (édition d'occurrence), E1/E2 (centimes et normalisation), C1/C2/C3 (pagination), K1, K3, G7/G8, puis le reste. Chaque correction inverse son test `bug_<ID>` | selon le bug | Test inversé + smoke ciblé |

Volume estimé : **environ 90 à 110 commits**. Les étapes 0 à 3 sont rapides et sans risque visible. L'essentiel du temps va aux étapes 4, 8 (dont le chat, à lui seul l'équivalent de deux features) et 10.

---

## 5. Stratégie de tests

| Niveau | Contenu | Outils |
|---|---|---|
| Unitaires (domaine pur) | Récurrence (mensuel au 31, 29 février, changement d'heure du 25/10, `until` et `count`), occurrences par mois et par jour, multi-jours, soldes (Σ = 0 attendu, sauf bugs caractérisés), plan de remboursement, répartitions, votes, regroupement des messages, permissions de groupe et de message, filtres, `DashboardSummary`, formatters, `ColorHex`, `InviteLink`, comparaison de versions, `redirect_policy`, `back_navigation_policy` | `flutter_test` |
| Mappers | Golden maps : nouveau `toFirestore` == ancien `toMap` ; aller-retour ; cas legacy (`expensesCustomCategories`, champs absents) | `flutter_test` |
| Repositories | Chemins, requêtes, `set` vs `update`, comportement en cas d'erreur | `fake_cloud_firestore` (D4) |
| Controllers et providers | `ProviderContainer` + overrides avec des fakes de repository (fakes écrits à la main, plus lisibles ; `mocktail` pour les ports à interactions) | `flutter_test`, `mocktail` (D4) |
| Widgets | Parcours critiques + goldens des écrans clés (référence capturée avant l'étape 6) | `flutter_test`, `matchesGoldenFile` |
| Architecture | Règles d'imports, interdiction des couleurs et styles en dur, taille max des fichiers | test Dart maison (sans dépendance) |
| Rules | Matrice flux légitimes v1.1.3 + attaques | `firebase-tests/` : `@firebase/rules-unit-testing`, `vitest`, émulateur |
| Functions | Payloads, destinataires, parsing ; triggers sur émulateur | `vitest`, émulateur |

Objectif de couverture : **≥ 90 % sur `domain/` et `data/mappers`**, pas de cible chiffrée sur la présentation (« couvrir la logique métier, pas faire du chiffre »).

## 6. Vérification

### 6.1 Porte qualité (chaque commit)

```bash
cd zyncro && dart format --set-exit-if-changed . && flutter analyze && flutter test && flutter build apk --debug
cd functions && npm run build && npm run lint && npm test          # dès l'étape 11 (build seul avant)
cd firebase-tests && npm test                                       # dès S1 et l'étape 0
```

`flutter analyze` doit renvoyer **0 issue** (infos comprises) à partir de l'étape 1.

### 6.2 Smoke manuel

Checklist en annexe A, sur un appareil Android, plus iOS pour les étapes 5, 8-chat et S2. Elle est exécutée intégralement aux étapes 4, 5, 8 et 9 et à chaque déploiement de rules ; sinon, seules les sections concernées.

### 6.3 Déploiements

Toujours depuis la racine git, et uniquement après ton accord explicite pour les rules (S1, S3) :
- `firebase deploy --only firestore:rules,storage` ;
- `firebase deploy --only firestore:indexes` (avant le client qui les utilise) ;
- `firebase deploy --only functions`.

---

## 7. Décisions à valider (questions bloquantes)

| # | Question | Ma recommandation |
|---|---|---|
| **D1** | Lancer **S1 (correctif des rules rétro-compatible) maintenant**, sur `fix/security-rules` depuis `main`, puis déployer après le vert de l'émulateur, **avant** le refactor ? | **Oui, en priorité absolue** : les failles sont exploitables sans compte. Prévoir d'accepter la liaison IAM Storage → Firestore dans la console |
| **D2** | État réel dans la console : (a) les rules déployées sont-elles celles du dépôt ? (b) l'enforcement App Check est-il activé sur Firestore et Storage ? (c) Play Integrity et App Attest sont-ils configurés ? (d) quel est l'id App Store et l'empreinte Play App Signing ? | Nécessaire pour S2 et pour valider l'hypothèse de l'AUDIT §10.6 |
| **D3** | Accord de principe sur une **mise à jour forcée** (`minimum_version`) pour S3 : adhésion via callable, timestamps serveur (K4), enforcement App Check. Quel calendrier ? | Oui, avec une release N compatible puis une hausse de `minimum_version` 2 à 4 semaines après |
| **D4** | Nouvelles dépendances. Dev Flutter : `mocktail`, `fake_cloud_firestore`. Functions : `eslint`, `typescript-eslint`, `vitest`. Nouveau package `firebase-tests/` : `@firebase/rules-unit-testing`, `vitest`. Runtime, optionnel : `cached_network_image` (cache disque des images) | Oui pour les dépendances de dev. Pour `cached_network_image` : oui (gain réel, sans changement visible). **Non** à freezed, json_serializable, riverpod_generator et very_good_analysis : pas de codegen, et `flutter_lints` + règles explicites suffisent |
| **D5** | Politique des bugs : le refactor les **conserve tous** et l'étape 13 les corrige. Souhaites-tu une **voie rapide** de correctifs, juste après S1 et avant le gros du refactor, pour les bugs qui corrompent des données : G1, D1, K2/E8/E9, G7/G8 ? Sur `main` (release rapide) ou sur la branche du refactor ? | Voie rapide **sur `main`** pour G1 et D1 (risque faible, impact fort) ; le reste à l'étape 13 |
| **D6** | Hygiène : retirer `functions/node_modules` et `functions/lib` du suivi git, épingler Flutter `3.41.5` dans les workflows de déploiement, ajouter une CI de PR | Oui |
| **D7** | Supprimer le code mort : `GroupSettingsScreen` + route `/group-settings`, `MediaSwipeViewer`, `AppUser` (sera recréé dans le domaine), `watchUnreadCount`, `settleExpense`, `sharePerPerson`, `untilController` | Oui. Seule exception : `CalendarFilters`, conservé dans le mapping, puisque le champ existe en base |
| **D8** | Functions : passer à Node 22 et mettre à jour `firebase-functions` et `firebase-admin` **dans** l'étape 11, ou dans une étape séparée ensuite ? | Étape séparée juste après la 11 : on ne change pas la structure et le runtime dans le même déploiement |
| **D9** | Galerie médias paginée (scroll infini, même contenu chargé progressivement) : acceptable au titre du « comportement identique » ? | Oui |
| **D10** | Conventions : renommer `IXxxRepository` → `XxxRepository` (domaine) et `FirestoreXxxRepository` (data) ; imports `package:` partout ; écrans ≤ 150 lignes visés | Oui |

---

## Annexe A — Checklist de non-régression (smoke manuel)

Elle est issue des inventaires de l'audit. Chaque ligne est un comportement **actuel** à préserver, bugs compris.

**Auth (A)**
- Connexion par e-mail, réinitialisation du mot de passe.
- Google ; Apple (iOS uniquement).
- Invité avec pseudo d'au moins 2 caractères.
- Inscription (nom, e-mail, mot de passe, confirmation).
- Profil :
  - photo depuis la caméra ou la galerie, retour à la photo du fournisseur, initiales ;
  - pseudo global, interrupteur photo, interrupteur notifications ;
  - déconnexion, suppression du compte.
- Lien d'invitation ouvert hors connexion : rejoué après le login.

**Groupes (G)**
- Liste réordonnable par glisser.
- Badge de non-lus « 99+ ».
- Copie du code au tap.
- Création : 8 emojis, nom ≤ 30, description ≤ 150.
- Rejoindre par code de 6 caractères, avec message système.
- Lien `/i/CODE` :
  - aperçu (photo, sinon emoji, sinon initiale) ;
  - « Ouvrir cet espace » si déjà membre ;
  - écran « lien invalide ».
- Réglages de l'accueil (HS) :
  - emoji, photo, nom et description (propriétaire) ;
  - code : générer, copier, partager, régénérer ;
  - couleur du thème et couleurs perso ;
  - pseudo unique ;
  - nommer propriétaire, retirer un membre ;
  - quitter (bloqué pour le propriétaire) ;
  - supprimer le groupe.
- Changement de groupe : retour à `/groups`.

**Dashboard (D)**
- 3 prochains événements (non étendus).
- Note épinglée (non tappable).
- Total des dépenses et solde.
- 3 derniers messages, libellés par type.
- 6 médias, « Voir tout » vers la galerie.
- Actions rapides événement et note.

**Calendrier (CA)**
- Navigation entre mois, grille commençant le lundi, aujourd'hui en dégradé.
- Indicateurs en bande (2 max) ou en point (3 max).
- Sélection d'un jour, titre « d MMMM » ou « Événements du mois ».
- Vue agenda groupée par jour, « Aujourd'hui » / « Demain ».
- Recherche sur titre et lieu.
- Filtres : participants, « récurrents uniquement ».
- Formulaire :
  - titre ≤ 50 ; début à 9h00 par défaut ; fin optionnelle ≥ début ;
  - palette et couleurs perso (ajout HSV, suppression par appui long) ;
  - participants ;
  - récurrence : jour, semaine, mois, an ; toujours, N fois ou jusqu'au ;
  - rappel : aucun, 0, 10, 60, 1440 min ou personnalisé.
- Suppression de la série.
- Messages système à la création, l'édition et la suppression.
- Réglages : couleur, bande ou point.

**Notes (N)**
- Recherche sur titre, contenu et items.
- Notes épinglées en pleine largeur, grille sur 2 colonnes, épingler depuis la carte.
- Éditeur :
  - titre ≤ 50, couleur, épingler ;
  - checklist : ajouter, retirer, réordonner ; un item coché passe en fin ; Entrée ajoute un item ;
  - sauvegarde explicite.
- Suppression confirmée.
- Messages système.

**Dépenses (E)**
- Onglets Dépenses / Équilibre ; FAB sur l'onglet 0.
- Recherche sur titre, catégorie et payeur.
- Totaux « Total dépenses » et « Votre part ».
- Carte de dépense :
  - couleur de la catégorie, ou vert pour un remboursement ;
  - montant abrégé en k/M ;
  - date relative.
- Équilibre :
  - carte de solde ;
  - soldes par membre ;
  - suggestions de remboursement, bouton « Rembourser » pré-rempli ;
  - message « équilibrés ».
- Formulaire :
  - titre ≤ 50 ; montant > 0 et ≤ 999 999,99 ; date entre 2020 et aujourd'hui ;
  - payeur et participants (le dernier ne peut pas être retiré) ;
  - répartition égale, par montant ou en %, avec redistribution automatique ;
  - récurrence ;
  - catégorie, avec création en ligne.
- Remboursement.
- Réglages : couleur, 7 devises, catégories avec icône et couleur.
- Messages système : ajout, modification, suppression, remboursement.

**Chat (CH)**
- Liste :
  - liste inversée, pagination par 50 à 300 px du haut ;
  - regroupement par expéditeur en dessous de 3 min ;
  - fond en couleur ou en image ;
  - retour en bas après l'envoi.
- Types de message :
  - texte avec liens cliquables et aperçu du premier lien ;
  - message système ;
  - image, vidéo, album.
- Audio :
  - lecture, seek, ±5 s, vitesse 1× ou 2× ;
  - enregistrement : chrono, annuler, valider, gestion du refus de permission.
- Sondage :
  - choix unique ou multiple, création et édition (2 à 5 options) ;
  - remise à zéro des votes à l'édition.
- Gestes sur un message :
  - tap : affiche l'heure et « modifié » ;
  - double tap : ❤️ ;
  - swipe : répondre (haptique, seuil 56 px).
- Appui long :
  - 6 emojis ;
  - répondre, copier ;
  - modifier, modifier le sondage ;
  - télécharger ;
  - supprimer, avec confirmation.
- Réactions avec détail par membre.
- Réponse : scroll vers l'original et surbrillance, ou « Message introuvable ».
- Indicateurs :
  - « vu par » ;
  - « en train d'écrire » (effacé après 4 s).
- Recherche.
- Menus radiaux « + » et caméra : photo, vidéo, galerie (10 max).
- Réglages : couleur, fond aucun / couleur / image, lien vers la galerie.

**Médias et partage (M)**
- Viewers :
  - plein écran immersif ;
  - zoom de 0,5 à 5× ;
  - appui long : enregistrer dans la galerie ;
  - vidéo en lecture auto et en boucle, play/pause/seek ;
  - compteur « i / n ».
- Galerie sur 3 colonnes, badges d'album.
- Picker :
  - permissions et accès limité (iOS et Android) ;
  - pagination par 80 ;
  - sélection numérotée, 10 max.
- Partage Android :
  - SEND et SEND_MULTIPLE ;
  - Direct Share (4 groupes) ;
  - écran d'envoi vers un groupe avec compression ;
  - liens d'invitation filtrés.

**Notifications (NT)**
- Tap à froid et à chaud : bon groupe et bon onglet.
- Bannière in-app groupée sur 600 ms, masquée si l'on est déjà sur l'écran.
- Notifications effacées au retour au premier plan et au changement de groupe.
- Rappels locaux d'événements.
- Dialog de mise à jour, obligatoire ou optionnelle.
