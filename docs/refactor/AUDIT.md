# Audit Zyncro — Phase 0

> Date : 2026-11-11 · Commit audité : `60188f1` (branche `main`, version `1.1.3+202`)
> Périmètre : `zyncro/` (Flutter), `functions/`, `firestore.rules`, `storage.rules`, `hosting/`, CI.
> Aucune modification de code. Les bugs fonctionnels sont détaillés dans [`BUGS_FOUND.md`](BUGS_FOUND.md) (identifiants `K*`, `C*`, `E*`…) ; ce document s'y réfère.

## Légende des références

Chemins Dart relatifs à `zyncro/lib/`. Alias utilisés pour les fichiers les plus cités :

| Alias | Fichier | Alias | Fichier |
|---|---|---|---|
| CHAT | `features/chat/presentation/screens/chat_screen.dart` | DB | `features/dashboard/presentation/screens/dashboard_screen.dart` |
| MV | `features/chat/presentation/screens/media_viewer_screen.dart` | HS | `features/dashboard/presentation/screens/home_settings_screen.dart` |
| MG | `features/chat/presentation/screens/media_gallery_screen.dart` | GSEL | `features/groups/presentation/screens/group_selection_screen.dart` |
| MP | `features/chat/presentation/screens/media_picker_screen.dart` | GSET | `features/groups/presentation/screens/group_settings_screen.dart` |
| STG | `features/chat/presentation/screens/share_to_group_screen.dart` | JL | `features/groups/presentation/screens/join_by_link_screen.dart` |
| CSET | `features/chat/presentation/screens/chat_settings_screen.dart` | GP | `features/groups/presentation/providers/groups_provider.dart` |
| MPV | `features/chat/presentation/providers/messages_provider.dart` | GR | `features/groups/data/repositories/groups_repository.dart` |
| SP | `features/chat/presentation/providers/share_provider.dart` | TSR | `features/groups/data/repositories/tab_settings_repository.dart` |
| MR | `features/chat/data/repositories/messages_repository.dart` | NS / NE | `features/notes/presentation/screens/notes_screen.dart` / `note_editor_screen.dart` |
| CAL | `features/calendar/presentation/screens/calendar_screen.dart` | LG / PR | `features/auth/presentation/screens/login_screen.dart` / `profile_screen.dart` |
| EVF | `features/calendar/presentation/screens/event_form_screen.dart` | CPR | `shared/widgets/color_picker_row.dart` |
| EXS | `features/expenses/presentation/screens/expenses_screen.dart` | RU | `shared/utils/recurrence_utils.dart` |
| EXF | `features/expenses/presentation/screens/expense_form_screen.dart` | TS | `shared/models/tab_settings.dart` |
| RF | `features/expenses/presentation/screens/reimbursement_form_screen.dart` | RT | `app/router.dart` |
| EXP | `features/expenses/presentation/providers/expenses_provider.dart` | NOTIF | `core/services/notification_service.dart` |
| FR / SR | `firestore.rules` / `storage.rules` (racine) | FN | `functions/src/index.ts` |

---

## 0. Résumé exécutif

1. **🔴 Failles de sécurité critiques, exploitables aujourd'hui en production**, confirmées sur l'émulateur avec une copie des rules actuelles (§10.6). N'importe quel utilisateur, y compris anonyme (connexion « invité » sans compte), peut :
   - lister tous les codes d'invitation, donc obtenir les `groupId` de tous les groupes ;
   - s'ajouter lui-même à n'importe quel groupe et en lire messages, dépenses, notes, événements et médias ;
   - se nommer propriétaire, retirer tous les membres, puis supprimer le groupe ;
   - écraser la photo d'un groupe, et uploader dans le Storage de n'importe quel groupe.

   App Check n'offre aucune protection : le provider *debug* est utilisé en production. Je recommande un **correctif des rules rétro-compatible, en urgence, avant le refactor** (PLAN, étape S1).
2. **Architecture** :
   - 21 fichiers de plus de 300 lignes concentrent 76 % du code (17 636 lignes sur 23 192). `CHAT` à lui seul fait 4 203 lignes.
   - La logique métier (soldes, répartitions, récurrences, sondages, permissions) vit dans les widgets.
   - Les modèles importent `cloud_firestore` (pas de couche domaine pure).
   - Les repositories instancient `FirebaseFirestore.instance` en dur, donc ne sont pas testables.
   - 4 écrans ou providers accèdent à Firebase sans passer par un repository.
3. **Qualité** :
   - 0 test.
   - Lints de base : 24 infos. Un jeu strict (§12) en remonte 726.
   - Valeurs en dur : 740 `Colors.`, 107 `Color(0x…)`, 276 `TextStyle(`, environ 600 chaînes FR.
   - Pas de thème sombre possible en l'état.
   - Hex → Color parsé à la main dans 7 endroits ; compression d'image dupliquée 3 fois ; écran de réglages du groupe dupliqué à environ 600 lignes près (dont une copie morte).
4. **Données** :
   - Requêtes non bornées : événements, dépenses, notes, médias et compteur de non-lus lisent tout l'historique.
   - Aucun index composite déclaré (ni dans le repo, ni en prod : `firebase firestore:indexes` renvoie `[]`).
   - Horodatage des messages côté client : c'est la cause du bug connu « messages en dernier » (K4).
   - Un seul document malformé fait planter tout l'onglet pour tous les membres (D1).
5. **Bugs connus** : les 4 causes racines sont identifiées (K1–K4). Plus de 80 autres bugs latents sont listés dans `BUGS_FOUND.md`. Les plus graves :
   - perte de mises à jour sur `config/tabSettings`, avec réinitialisation possible de tous les onglets (G1) ;
   - éditer une occurrence d'un événement ou d'une dépense récurrente modifie toute la série (K2, E8) ;
   - erreurs d'arrondi qui faussent les soldes (E1, E2) ;
   - trou dans la pagination du chat (C1) ;
   - double notification à la suppression d'un groupe, et « Tu as été retiré du groupe » envoyé à celui qui part de lui-même (G7, G8).
6. **Dépôt et outillage** :
   - `functions/node_modules` (5 776 fichiers) et `functions/lib` sont versionnés.
   - La CI ne fait que déployer : ni analyze ni tests, et la version de Flutter flotte (`3.x`).
   - Les Cloud Functions tiennent en un seul fichier, sans lint ni nettoyage des tokens FCM invalides.

---

## 1. Méthode et mesures de référence

| Mesure | Valeur |
|---|---|
| Fichiers Dart (`lib/`) | 77 (23 192 lignes) |
| Fichiers > 300 lignes | 21 (17 636 lignes) |
| `flutter analyze` (lints actuels) | 24 infos : 12 `deprecated_member_use` (RadioGroup), 7 `use_build_context_synchronously`, 4 `curly_braces`, 1 autre |
| `flutter analyze`, jeu strict proposé (sur une copie hors repo) | 726 : 299 `always_use_package_imports`, 108 `sort_constructors_first`, 87 `discarded_futures`, 58 `avoid_catches_without_on_clauses`, 22 `unawaited_futures`, 26 `inference_failure_*`, 9 `argument_type_not_assignable` (strict-casts)… |
| `flutter test` | « No tests were found » (`test/widget_test.dart` est vide) |
| `functions` : `tsc --noEmit` | OK (mode `strict` activé), aucun lint configuré |
| Index Firestore déployés | aucun (`indexes: []`) |
| Rules : PoC émulateur | 12 attaques sur 12 réussissent, 2 contrôles sur 2 restent refusés (§10.6) |

Méthode suivie :
- **Lecture directe** : rules, functions, hosting, modèles, repositories, providers, router, services core, thème.
- **Audits parallèles par feature** (chat, médias/partage, calendrier, dépenses, dashboard/groupes/notes/auth), chaque constat vérifié avec sa ligne.
- **Preuve de concept sur émulateur** (Firestore + Storage), lancée sur une copie des rules, sous un projet `demo-` fictif.

---

## 2. Cartographie actuelle

### 2.1 Arborescence et responsabilités

```
zyncro/lib/
├─ main.dart                 bootstrap (Firebase, App Check, timezone, reminders, FCM)
├─ app/app.dart              MaterialApp.router + observers + keep-alive de 3 providers
├─ app/router.dart (485)     GoRouter + redirect + _AppShell (top bar, bottom nav, couleurs d'onglet)
├─ core/constants/           AppColors, catégories de dépenses, InviteLink
├─ core/services/            notification (statique, tient un WidgetRef), reminder (statique),
│                            update, share_shortcuts (MethodChannel), group_activity (statique)
├─ core/theme/app_theme.dart thème clair uniquement
├─ core/utils/               extension d'erreurs de stream, partage d'invitation
├─ shared/models/            TOUS les modèles (dépendent de cloud_firestore) ; AppUser est mort
├─ shared/utils/             recurrence_utils (événements ET dépenses)
├─ shared/widgets/           avatar, settings tiles, color picker (451 l.), category editor
└─ features/
   ├─ auth/       data (repo + UserProfileService), domain (interface exposant firebase_auth.User), presentation
   ├─ groups/     data (groups + tab_settings), domain (interface), presentation (sélection, réglages [morts], join by link)
   ├─ chat/       data (messages + storage), domain (interface), presentation (chat 4203 l., viewer, galerie, picker, partage, réglages)
   ├─ calendar/   data, domain (interface), presentation (calendar 942 l., form 997 l., réglages)
   ├─ expenses/   data, domain (interface), presentation (liste 925 l., form 1137 l., remboursement, réglages)
   ├─ notes/      data, domain (interface), presentation (liste, éditeur, réglages)
   └─ dashboard/  presentation uniquement (dashboard 814 l., home_settings 938 l.)
```

Les dossiers `domain/` ne contiennent que des interfaces de repository, et ces interfaces référencent les modèles de `shared/models` (couplés à Firestore). Il n'y a ni `data/models`, ni `mappers`, ni entités.

### 2.2 Dépendances entre features (imports réels)

```
dashboard ─► calendar, expenses, notes, chat, groups, auth
chat      ─► groups(7), auth(4), expenses(1 : expenseMembersProvider, CHAT:21)
calendar  ─► groups(7), chat(1 : message système), auth
expenses  ─► groups(7), chat(2 : messages système), auth
notes     ─► groups(6), chat(1 : message système), auth
groups    ─► chat(3 : messages système), auth(5)
core/services/notification_service ─► features/groups + app/router   (core dépend des features)
features/groups/.../invite_link_provider ─► app/router                (feature dépend du router)
features/chat/.../share_provider        ─► app/router                (idem)
app/router ─► toutes les features
```

Problèmes :
- **Cycles** : `router ↔ invite_link_provider`, `router → share_to_group_screen → share_provider → router`, et `app → notification_service → router`.
- **Feature `chat` utilisée comme bus d'activité** : 5 features appellent `messagesRepositoryProvider.sendSystemMessage` depuis leurs widgets (exemples : EXF:472, EVF:152, NE:174, HS:405, GSEL:648).
- **`chat` dépend de `expenses`** pour obtenir la liste des membres (CHAT:21, 1211).

### 2.3 Flux de données

```
Lecture : Firestore ──snapshots()──► Repository (FirebaseFirestore.instance en dur, fromMap à casts stricts)
              └─► StreamProvider global (non autoDispose), scopé par selectedGroupIdProvider
                    └─► ConsumerStatefulWidget de 400 à 4200 lignes : filtrage, agrégation, calculs, rendu
Écriture : Widget ──► repository.create/update(model.toMap()) ──► + message système chat (même widget)
                  └─► parfois directement FirebaseFirestore/Storage.instance (HS, PR, CSET, MPV)
Serveur : triggers Firestore (FN) ──► FCM multicast ──► NotificationService (statique) ──► router.go()
Local : SharedPreferences (groupe sélectionné, ordre, activité, rappels, préférence notif)
        flutter_local_notifications (rappels d'événements)
```

### 2.4 Schéma de données actuel (contrat de rétro-compatibilité)

Ce schéma est **figé** pendant le refactor (règle n°1).

| Chemin | Champs écrits par v1.1.3 | Remarques |
|---|---|---|
| `config/app_version` | `minimum_version`, `latest_version`, `{android,ios}_{minimum,latest}_version`, `{android,ios}_url` | Lecture publique ; sert au mécanisme de mise à jour forcée (`core/services/update_service.dart:21-66`) |
| `users/{uid}` | `fcmToken`, `updatedAt`, `photoUrl`, `showProfilePhoto` | Un seul token par utilisateur (NOTIF:142-145) |
| `invite_codes/{CODE}` | `groupId`, `groupName`, `groupEmoji` | 6 caractères, sans expiration |
| `groups/{gid}` | `name`, `description`, `emoji`, `photoUrl`, `memberIds[]`, `createdBy`, `createdAt`, `inviteCode` | `createdBy` = propriétaire (rules) |
| `…/members/{uid}` | `uid`, `displayName`, `role` (`owner`/`member`), `joinedAt`, `photoUrl`, `showProfilePhoto`, `lastReadMessageId`, `lastReadAt` | Le rôle a deux sources de vérité : `role` et `createdBy` |
| `…/messages/{id}` | `groupId`, `senderId`, `senderName`, `content` (texte ou **JSON encodé** selon `type`), `type` (`text`/`system`/`image`/`file`=vidéo/`poll`/`audio`), `timestamp` (horloge client), `editedAt`, `reactions{emoji:[uid]}` (sert aussi aux votes), `replyTo*`, `notifScreen` | `type` est lu avec `values.byName` : toute nouvelle valeur casse les anciennes versions |
| `…/typing/{uid}` | `name`, `updatedAt` | |
| `…/expenses/{id}` | `groupId`, `title`, `amount` (double), `paidBy`, `paidByName`, `splitWith[]`, `settled`, `category` (**nom**), `date`, `createdBy`, `createdAt`, `expenseType`, `splitType`, `splitAmounts{uid:double}`, `updatedBy`, `recurrence{frequency,endType,count,until}` | |
| `…/events/{id}` | `groupId`, `title`, `description`, `startDate`, `endDate`, `location`, `createdBy`, `creatorName` (jamais écrit), `createdAt`, `color`, `updatedBy`, `recurrence`, `participantIds[]` | |
| `…/notes/{id}` | `groupId`, `title`, `content`, `isPinned`, `color`, `isChecklist`, `checklist[{text,done}]`, `createdBy`, `createdAt`, `updatedAt`, `updatedBy` | |
| `…/config/tabSettings` | `customColors`, `hiddenBaseColors`, `{home,calendar,notes,expenses,chat}ThemeColor`, `chatBackgroundType/Value`, `expensesCurrency`, `expensesCategories[{name,iconKey,colorHex}]`, `expensesCustomCategories` (lecture legacy), `calendarDisplayMode`, `calendarCustomCategories`, `calendarFilters`, `homePhotoUrl` | Réécrit **en entier** à chaque modification (TSR:24-26) |
| Storage | `profile_photos/{uid}.jpg`, `audio/{gid}/{msgId}.m4a`, `media/{gid}/{msgId}[_i].{ext}`, `group_photos/{gid}.jpg`, `chat_backgrounds/{gid}.jpg` | URLs `getDownloadURL` (avec token) stockées dans les documents |

---

## 3. Problèmes classés par sévérité

### 🔴 Sécurité / bugs latents majeurs

Le détail des failles est en §10, celui des bugs dans `BUGS_FOUND.md`.

| ID | Problème | Références |
|---|---|---|
| S-01 | Auto-adhésion à n'importe quel groupe sans code d'invitation, puis lecture de toutes ses données | FR:80, FR:59-62 |
| S-02 | `invite_codes` est listable par tout utilisateur connecté (`read` inclut `list`), ce qui révèle tous les `groupId` | FR:37 |
| S-03 | Escalade de privilèges : tout membre peut modifier `createdBy`/`memberIds` du groupe et le `role` de n'importe quel membre, puis supprimer le groupe | FR:59-73, FR:81 |
| S-04 | Messages : tout membre peut éditer ou supprimer les messages des autres, usurper `senderId`, forger `timestamp`, réécrire les votes | FR:89-91 |
| S-05 | Storage : aucune vérification d'appartenance. Lecture et listage des médias de tout groupe, upload partout, écrasement ou suppression de `group_photos` et `chat_backgrounds`, aucune limite sur `profile_photos` | SR:8-51 |
| S-06 | App Check inopérant en production (`AndroidDebugProvider`, aucun provider Apple explicite) | `main.dart:20-22` |
| D1 | `fromMap` à casts stricts (`as String`, `as Timestamp`, `values.byName`). Un seul document malformé (aucune validation dans les rules) fait échouer tout le stream de l'onglet, pour tous les membres. L'erreur est parfois affichée comme une liste vide | `shared/models/*.dart` (p. ex. `expense.dart:56-72`, `message.dart:37-42`), EXS:128 |
| G1 | `config/tabSettings` réécrit en entier à partir d'un instantané local. Les modifications concurrentes sont perdues, et une écriture pendant le chargement réinitialise tous les onglets aux valeurs par défaut | TSR:24-26, HS:521, NE:244 |
| K4 | Horodatage client des messages : l'ordre du chat dépend de l'horloge de chaque téléphone | MR:134, 176, 212, 252, 302, 332 |

### 🟠 Architecture et maintenabilité

| ID | Problème | Références |
|---|---|---|
| A-01 | Fichiers monolithiques : `CHAT` (4203), EXF (1137), MV (1044), EVF (997), CAL (942), HS (938), EXS (925), DB (814), GSET (777), GSEL (728)… `_ChatScreenState` à lui seul couvre CHAT:37-1940 | §1 |
| A-02 | Pas de domaine pur : les modèles importent `cloud_firestore` (`Timestamp`), et l'interface d'auth expose `firebase_auth.User` | `shared/models/event.dart:1`, `features/auth/domain/repositories/i_auth_repository.dart:1` |
| A-03 | Pas de DTO ni de mappers ; `toMap` et `fromMap` sont mêlés aux entités. `copyWith` ne permet pas de remettre un champ nullable à `null` (à l'origine de K3, CA1, E18) | `shared/models/event.dart:78-106`, `expense.dart:108-144`, `note.dart:84-107` |
| A-04 | Repositories non injectables (`final _db = FirebaseFirestore.instance`). `TabSettingsRepository` et `UserProfileService` n'ont pas d'interface | `features/*/data/repositories/*.dart:8` |
| A-05 | Accès Firebase et plugins depuis la présentation : §5 | HS:139-202, PR:196-213, CSET:80, MPV:161-184 |
| A-06 | Logique métier dans les widgets : §4 | |
| A-07 | Couplages et cycles entre features et router, chat utilisé comme bus d'activité : §2.2 | |
| A-08 | Services statiques, non testables. `NotificationService` garde un `WidgetRef` dans des closures statiques et appelle `routerProvider` | NOTIF:33-138, `core/services/reminder_service.dart`, `group_activity_service.dart` |
| A-09 | Gestion d'erreurs absente : 37 `catch (_)` ou `on FirebaseException {}` silencieux ; `throw Exception('…')` avec du texte UI (GR:286) ; environ 15 snackbars affichent l'exception brute `'Erreur : $e'` (HS:178, GSET:96, NE:181…) ; aucun type `Failure` ; pas de logging structuré ni de crash reporting | |
| A-10 | Strings magiques Firestore (`'groups'`, `'members'`, noms de champs) dans 15 fichiers | |
| A-11 | Router monolithique : routes + redirect + widget shell de 260 lignes + couleurs d'onglet, avec un effet de bord dans `build` (`addPostFrameCallback` à chaque build, RT:246-248). Navigation impérative en `MaterialPageRoute` (CAL:319, EXS:156, DB:144, NS:36, CHAT:735…) mêlée à GoRouter | RT |
| A-12 | Le `TabSettings` monolithique mélange 5 onglets (TS:45-220) ; filtres et palettes sont partagés à tort entre membres ou entre modules (G2, CA10). Il n'y a pas de système générique pour les réglages d'onglet | TS |
| A-13 | Duplication massive : §6 | |
| A-14 | Couverture de tests nulle, aucun test des rules ni des functions | |
| A-15 | Cloud Functions monolithiques (462 lignes, 14 triggers), aucun lint, réponses FCM ignorées, aucune idempotence | §11 |
| A-16 | Code mort : `GroupSettingsScreen` + route `/group-settings` (aucune navigation), `MediaSwipeViewer` (MV:472-655), `AppUser`, `settleExpense` (ER:76-78), `watchUnreadCount` (MR:397-416, remplacé par MPV:174), `Expense.sharePerPerson`, `CalendarFilters` (lu et écrit, jamais utilisé), `untilController` (EVF:262) | |
| A-17 | Hygiène du dépôt : `functions/node_modules` (5 776 fichiers) et `functions/lib` versionnés ; CI sans analyze ni test ; Flutter `3.x` flottant dans les workflows de déploiement ; aucun `predeploy` de build des functions dans `firebase.json` (un déploiement sans build envoie le `lib/` versionné, potentiellement périmé) | `.github/workflows/*.yml`, `firebase.json` |
| A-18 | Le partage vers Zyncro n'existe pas sur iOS : aucune Share Extension, aucun App Group, aucun schéma `ShareMedia-*` | `zyncro/ios/Runner/Info.plist:58-78`, `Runner.entitlements` |
| A-19 | Riverpod : un seul `.select(` utile dans tout le code ; aucun `autoDispose` hors deux `family` ; 4 streams `watchMembers` identiques (GP:94, GP:140, GSET:15, EXP:22) | |

### 🟡 Style et cohérence

| ID | Problème | Références |
|---|---|---|
| Y-01 | Couleurs et styles en dur : 740 `Colors.`, 107 `Color(0x…)`, 276 `TextStyle(`. `0xFFF7F9FC` (= `AppColors.background`) est réécrit plus de 15 fois (CHAT:347, CAL:241, DB:115, NS:64…). Les accents diffèrent selon les écrans (`0xFFE85D75` dans MP, gradients d'onglet dans RT:173-179 / DB:29-35 / HS:523). `Theme.of` = 0 dans DB, HS, GSET, NE | |
| Y-02 | Thème clair uniquement (`ColorScheme.light`) ; le thème n'est appliqué qu'au shell (RT:256) | `core/theme/app_theme.dart:9` |
| Y-03 | Aucune l10n, environ 600 chaînes FR en dur. Libellés de navigation en anglais (« Home », « Calendar », RT:217-231) mais titres en français (RT:208). Pluriels faits à la main (HS:624, NS:343). `'fr_FR'` en dur (CAL:223, 357, EVF:431). « Anonyme » / « Membre » / « Quelqu'un » coexistent comme nom par défaut | |
| Y-04 | Formats divergents : temps relatif selon deux règles différentes (DB:59-64 vs NS:15-23) ; montants abrégés en k/M (EXS:34-50) ; durées sans les heures (MV:284) | |
| Y-05 | Lints dépréciés (`Radio.groupValue`, 12 occurrences) ; `pubspec.yaml` : description « A new Flutter project. », `flutter_lints ^5`, contrainte figée et non commentée `cloud_firestore ">=6.1.3 <6.3.0"` | `pubspec.yaml` |
| Y-06 | Conditions mortes : `isFirstInGroup ? 4 : 4` (CHAT:2231), `isMe ? d.delta.dx : d.delta.dx` (CHAT:3237) | |
| Y-07 | Mélange d'imports relatifs et absolus, ordre non trié (27 `directives_ordering`) | |

---

## 4. Logique métier présente dans les widgets

| Domaine | Où | Cible |
|---|---|---|
| Soldes par membre | EXP:29-44 (provider), utilisé dans EXS:137 et DB:78 | `expenses/domain/services/balance_calculator.dart` |
| Simplification des dettes (greedy, seuil 0,01) | EXS:61-94, appelée dans `build` (EXS:399) | `settlement_planner.dart` |
| Répartition égale / montants / % : défauts, redistribution, validation ±0,01 / ±0,1 %, conversions | EXF:90-207, EXF:607-608 | `split_calculator.dart` |
| Totaux « Total dépenses » / « Votre part » | EXS:143-149, DB:99-100 | `expense_stats.dart` |
| Expansion des récurrences (événements **et** dépenses) | RU:7-140 | `shared/domain/recurrence/recurrence_expander.dart` |
| Jours, mois, agenda, grille, filtres du calendrier | CAL:189-289, 309-313, 525-527 | `calendar_day_index.dart`, `event_filter.dart`, `month_grid.dart` |
| Combinaison date + heure, validation et orchestration de l'événement (repo + rappel + message) | EVF:120-121, 170-252 | `save_event` (use case), `EventFormController` |
| Parsing du JSON des messages (10 endroits) | CHAT:465, 494, 578, 2034, 2053, 2780, 3589 ; MV:509 ; MG:38, 246 | `chat/data/mappers/message_content_codec.dart` |
| Votes des sondages, exclusivité | CHAT:573-591, 3598-3608, 3704-3708 | `poll_tally.dart` |
| Regroupement des messages, positions | CHAT:286-296, 1437-1447 | `message_grouping.dart` |
| Permissions des messages (éditer, supprimer, répondre, réagir) | CHAT:372-407, 1476-1521 | `message_permissions.dart` |
| « Vu par », déclenchement de `markAsRead` | CHAT:1215-1270, 1402-1408 | `read_receipts.dart` + controller |
| Aperçu de lien (HTTP + scraping OpenGraph) | CHAT:2474-2554 | `link_preview_service.dart` (data) |
| Calcul du propriétaire, unicité du pseudo, validations 30/150/50 | HS:296-301, 529 ; GSET:55-60, 221 ; GSEL:547-564 ; NE:306-310 | `groups/domain/policies`, `validators.dart` |
| Rédaction des messages système (10 endroits) | HS:405, 470, 508 ; GSET:632, 683, 731 ; GSEL:648 ; JL:87 ; NE:174, 226 ; EXF:472, 495, 544 ; RF:109 ; EVF:155, 240 | port `ActivityLog` (shared/domain), implémenté par chat/data |
| Agrégations du dashboard | DB:85-108 | `dashboard_summary.dart` |
| Normalisation et ordre de la checklist | NE:93-115 | `notes/domain/services/checklist.dart` |
| Résolution de la photo effective et du nom par défaut (×3) | GSEL:448-461, 625-635 ; JL:59-71 | `member_profile_resolver.dart` |
| Couleur d'onglet, assombrissement HSL | RT:181-198, DB:24-48, CAL:15-27, CHAT:32-35 | `design_system` (`ColorHex`, `TabAppearance`) |

## 5. Accès Firebase et plugins hors repositories

| Fichier:ligne | Accès |
|---|---|
| HS:139, 158, 168, 190, 196 | `FirebaseFirestore.instance` + `FirebaseStorage.instance` (photo et emoji du groupe), `ImagePicker` (HS:150) |
| PR:196-213 | `FirebaseMessaging.instance` + Firestore (préférence notifications), SharedPreferences (PR:30, 191) |
| CSET:72-87 | `ImagePicker` + `FirebaseStorage.instance` (fond du chat) ; la variable locale `ref` masque le `ref` Riverpod |
| MPV:161-184 | `FirebaseFirestore.instance` dans des providers (non-lus), qui court-circuite MR:397-416 |
| NOTIF:35-36, 172 | Firestore, Auth et Messaging dans un service statique |
| `core/services/update_service.dart:23` | Firestore en statique |
| CHAT | `record` (122, 636-673), `path_provider` (644, 749, 851), `flutter_image_compress` (757, 854), `image_picker` (828-842), `just_audio` (3340), `video_player` (2712), `http` (2496), `url_launcher` (2026, 2609) |
| MV:15-61 | `MediaDownloader` (http + Gal + path_provider), défini dans un fichier d'écran et dépendant de `BuildContext` |
| MP:56-159 | `photo_manager` entièrement dans le `State` |
| STG:160-243 | Compression, `path_provider`, orchestration de l'envoi |
| SP:188 | `http.get` dans un Notifier (photo de groupe pour les raccourcis) |
| GSEL:1, LG:41, RG:46 | Types Firebase (`FirebaseException`, `FirebaseAuthException`) dans les widgets |
| `features/auth/presentation/providers/auth_provider.dart:21-26` | `userDocProvider` renvoie une `Map` brute, parsée dans l'UI (PR:297, GSEL:449) |

## 6. Duplication de code

| Duplication | Occurrences |
|---|---|
| `HomeSettingsScreen` et `GroupSettingsScreen` | environ 600 lignes clonées (pseudo, infos, code, membres, zone danger, `_Section`) : HS:206-938 vs GSET:34-777. GSET est **mort** |
| Parsing hex → Color | CPR:5, CHAT:1295, CAL:23, DB:47, DB:466, NS:12, RT:196 (aucune gestion d'erreur, sauf la variante de CPR) |
| Assombrissement HSL (−0,12) | CHAT:32, CAL:15, DB:24, RT:181 |
| Compression image (q85 / 1920 / sans EXIF) | CHAT:749-773, CHAT:850-866, STG:219-243 (repli MIME incohérent entre elles) |
| Upload Storage + `getDownloadURL` | MR:190-202, 231-243, 276-288 ; CSET:80-87 ; HS:158-165 ; `features/auth/data/services/user_profile_service.dart:55-60` |
| Feuille « Prendre une photo / Galerie » + test `contains('cancelled')` | HS:41-105, PR:82-150, CSET:55-95 |
| Téléchargement + enregistrement galerie | MV:16-37 ≈ MV:39-60 ; CHAT:463-473 |
| En-tête overlay des viewers ×4, barre vidéo ×2 | MV:143-215, 317-388, 573-650, 953-1039 ; MV:391-461, 785-845 |
| `_formatDateTime` ×4, `_fmtDuration` ×3, `DateFormat('HH:mm')` ×n | MV:99, 276, 515, 900 ; MV:284, 757, MP:161, CHAT:629, 3360 |
| Symboles de devise et formatage des montants | EXS:17-50 = `expenses_settings_screen.dart:14-22` ; DB:55-57 ; « € » en dur EXF:476, 499, 961, 989 ; RF:113 |
| Helpers de formulaire (`_parseDouble`, `_pickDate`, champ de date, chips de membres, bouton d'enregistrement, libellés de section ×8) | EXF:74-84, 628, 692-1035 ; RF:55-58, 138, 184-231 |
| Écriture de `TabSettings` (`_update`) ×5, câblage du `ColorPickerRow` ×4 | HS:33, NSet:13, NE:241, `expenses_settings_screen.dart:34`, CSET:24 |
| Dialogs de confirmation (environ 15) et snackbars d'erreur (77 `SnackBar(`) | voir les audits par feature |
| Dialogs de création et d'édition de sondage | CHAT:3816-4028 ≈ CHAT:4032-4203 |
| `_EventCard` ≈ `_AgendaEventCard` (environ 80 %) | CAL:744-853 / 855-942 |
| Libellés de fréquence de récurrence | `shared/models/recurrence_rule.dart:39-53` = EVF:275-280 = EXF:226-229 |
| Avatar de groupe (emoji, photo ou initiale) ×6 | HS:573-601, GSEL:243-268, JL:195-293, RT:326-356, GSET:237 |
| Nom d'expéditeur par défaut « Anonyme » ×6 | CHAT:163, 262, 610, 699, 728, 821 |

## 7. Streams, listeners et contrôleurs non fermés

| Où | Problème |
|---|---|
| NOTIF:66-68, 102 | `initialize()` annule `_tokenRefreshSub` et `_foregroundSub`, mais pas `_openedAppSub` avant de le recréer : listener en double si `initialize()` est rappelé sans logout |
| NOTIF:65-105 | Un `WidgetRef` est capturé dans des closures statiques (référence potentiellement invalide) |
| `unreadCountProvider.family` / `_memberLastReadAtProvider.family` (MPV:157-185) | Pas d'autoDispose : un listener Firestore par groupe affiché, jamais fermé de la session |
| Tous les `StreamProvider` des features | Globaux, sans autoDispose, et `ref.watch(...Repository)` recrée le stream si le provider change |
| EXF:213 (`countController`), EVF:260, 262, 599, HS:108, 207-208, 276, GSET:35, 103-104, PR:41 | `TextEditingController` jamais disposés |
| CHAT:655 | Double `Timer.periodic` possible si l'enregistrement est lancé deux fois |
| CHAT:60-64 | `_messageKeys` (une `GlobalKey` par message) n'est jamais purgé |
| CHAT:2713, MV:247, 723 | `initialize()` vidéo sans gestion d'erreur : Future en erreur non gérée, spinner infini |
| Fichiers temporaires | Audio `.m4a`, images compressées, `share_*`, `zyncro_*` (CHAT:644, 756, 852 ; STG:229 ; MV:21, 44) jamais supprimés |
| `setState` / `ref` après `await` sans `mounted` | CHAT:651, 665, 675 ; MP:127 ; RG:47 ; EXF:472, 495, 544 ; RF:109 ; et 7 lints `use_build_context_synchronously` (HS:270…) |
| Exceptions qui laissent l'UI bloquée | MP:56-159 (`_loading`, `_confirming` restent à true) ; PR:189-222 ; GSEL:445-472 |

## 8. Rebuilds inutiles et performance UI

| Où | Problème |
|---|---|
| CHAT:150, 160 | `setState` sur tout l'écran de 4200 lignes **à chaque frappe**, plus une écriture Firestore `setTyping` par frappe (sans throttle) |
| CHAT:655-659 | Chrono d'enregistrement : `setState` global chaque seconde |
| CHAT:1206, 1211, 1277, 1554 | `watch` de providers entiers (membres, `tabSettings`, typing) au niveau de l'écran. Chaque `markAsRead` d'un membre reconstruit l'écran de tout le monde |
| CHAT:1492-1504 | Recherche O(n) par item (membre, message cité), donc O(n²) sur la liste |
| CHAT:2034, 2053, 3589 ; MG:93 | `jsonDecode` dans `build` |
| CHAT:2489-2554 | Aperçu de lien : nouvelle requête HTTP à chaque montage de l'item, sans cache |
| CHAT:2712 | Un `VideoPlayerController` natif par vignette vidéo visible |
| DB:73-110 | 8 `watch` sans `select` : tout le dashboard se reconstruit à chaque message |
| EXS:771-773 | Chaque `_ExpenseCard` watch deux fois tout `tabSettingsProvider` |
| CAL:301-302, 525-527 | Filtrage à chaque frappe ; parcours O(n) par case de la grille |
| MV:254-259, 730 | `addListener(setState)` : rebuild complet à chaque tick vidéo |
| Images | 16 `Image.network`/`NetworkImage`, **0** `cacheWidth`/`cacheHeight`, pas de cache disque. Images pleine résolution dans des tuiles de 72 à 88 px (MG:205, 284, 354 ; STG:287, 338 ; CSET:227 ; fond plein écran CHAT:1286) |
| RT:246 | `addPostFrameCallback` posé à chaque build du shell |
| SP:150-153 | Resynchronisation des raccourcis Android (`removeAll` + `add`) à chaque émission de `userGroupsProvider` |

## 9. Requêtes Firestore non bornées et index

| Requête | Problème | Suggestion (PLAN, étape 10) |
|---|---|---|
| `watchEvents` (`features/calendar/data/repositories/events_repository.dart:14-23`) | Tous les événements depuis toujours, puis expansion complète à chaque snapshot | Fenêtre glissante par plage, plus un champ dénormalisé de fin de série (à valider) |
| `watchExpenses` (ER:14-24) | Toutes les dépenses ; le calcul des soldes **nécessite** l'historique complet | Garder le complet pour les soldes, paginer la liste ; à terme, soldes agrégés |
| `watchNotes` (`notes_repository.dart:13-28`) | Toutes les notes (volumétrie faible, acceptable) | Acceptable, à surveiller |
| `watchMediaMessages` (MR:50-62) | `whereIn type` **sans orderBy ni limit**, tri client. Le dashboard lit tout l'historique média pour afficher 6 vignettes (DB:107-108) | `orderBy(timestamp).limit(n)`, ce qui demande l'index composite `(type, timestamp desc)` |
| `unreadCountProvider` (MPV:174-185) | Télécharge **tous** les messages non lus, pour **chaque** groupe de la liste | `limit(100)`, affichage « 99+ » identique (GSEL:269-294), ou `count()` agrégé |
| `watchMessages` (MR:19-31) | Paginé (50 + `loadMore`), mais avec un trou de pagination (C1) | |
| `watchMembers` ×4, `watchUserGroups` | Bornés par la taille du groupe ou le nombre de groupes de l'utilisateur | Dédupliquer les streams |
| `updateMemberDisplayName` (GR:279-288) | `get()` de tous les membres sans transaction | |

`firestore.indexes.json` est absent, et **aucun index n'est déployé** (`firebase firestore:indexes` → `[]`). Les requêtes actuelles ne s'appuient que sur les index automatiques.

---

## 10. Audit sécurité

### 10.1 `firestore.rules` : collection par collection

| Chemin | Règle actuelle | Protégé par l'appartenance ? | Validation des champs | Verdict |
|---|---|---|---|---|
| `config/{doc}` | read public, write interdit (FR:22-25) | n/a | n/a | ✅ |
| `users/{uid}` | soi-même (FR:28-30) | n/a | aucune (taille, champs) | 🟡 |
| `invite_codes/{code}` | `read` (donc **list**), `create` et `delete` pour tout utilisateur connecté (FR:36-39) | ❌ | aucune | 🔴 S-02, 🟠 S-07 |
| `groups/{gid}` read | `uid in memberIds` (FR:45) | ✅ | | ✅ |
| `groups/{gid}` create | créateur dans `memberIds`, `createdBy == uid`, nom 1-30, description ≤ 150 (FR:48-56) | n/a | partielle | ✅ |
| `groups/{gid}` update | membre (`exists members/uid`) **ou** non-membre qui s'ajoute à `memberIds` ; seuls `name` et `description` sont validés (FR:59-70) | ⚠️ contournable (S-01) | `createdBy`, `memberIds`, `inviteCode`, `photoUrl` modifiables par n'importe quel membre | 🔴 S-01, S-03 |
| `groups/{gid}` delete | `createdBy == uid` (FR:73), mais `createdBy` est modifiable (S-03) | ⚠️ | | 🔴 |
| `members/{uid}` create | `auth.uid == memberId`, **sans aucune condition liée au groupe** (FR:80) | ❌ | aucune (`role: 'owner'` accepté) | 🔴 S-01 |
| `members/{uid}` update | tout membre, sur n'importe quel doc membre (FR:81) | ✅ mais trop large | aucune (`role`, `displayName` des autres) | 🔴 S-03 |
| `members/{uid}` delete | soi-même ou `createdBy` (FR:82-85) ; le propriétaire peut partir, ce qui laisse le groupe orphelin | ✅ | | 🟠 S-10 |
| `messages/{id}` | read, create, update, delete pour tout membre (FR:89-91) | ✅ | aucune (`senderId`, `timestamp`, `type`, taille) | 🔴 S-04, D1 |
| `typing/{uid}` | read membre, write soi-même (FR:94-97) | ✅ | aucune | ✅ |
| `expenses`, `events`, `notes` | read et write pour tout membre (FR:100-112) | ✅ | aucune : documents malformés (D1), `createdBy` usurpable | 🟠 S-08 |
| `config/{id}` (tabSettings) | read et write pour tout membre (FR:115-118) | ✅ | aucune (taille non bornée, 1 Mo max) | 🟠 S-08 |

Remarques transverses :
- **Deux sources de vérité pour l'appartenance** : `memberIds` (lecture du groupe) et `exists(members/uid)` (tout le reste). S-01 exploite cet écart.
- **La connexion anonyme est activée** (`features/auth/data/repositories/auth_repository.dart:64-69`), donc `request.auth != null` ne filtre rien : n'importe qui obtient un token en un appel.

### 10.2 `storage.rules`

| Chemin | Lecture | Écriture | Limites | Verdict |
|---|---|---|---|---|
| `profile_photos/{file}` | tout utilisateur connecté (`read` = get + **list**) | soi-même (`{uid}.jpg`) | **ni taille ni type** (PoC S5 : `text/html` accepté) | 🟠 |
| `audio/{gid}/{file}` | **tout utilisateur connecté, sans appartenance** (SR:18) | tout utilisateur connecté, dans tout groupe | < 50 Mo, `audio/*` déclaré par le client | 🔴 |
| `media/{gid}/{file}` | **idem**, listable (PoC S1, S2) | **idem** (PoC S4) | < 100 Mo, `image/*` ou `video/*` déclaré | 🔴 |
| `group_photos/{file}` | tout utilisateur connecté | **tout utilisateur connecté peut écraser ou supprimer la photo de n'importe quel groupe** (PoC S3) | < 10 Mo, `image/*` | 🔴 |
| `chat_backgrounds/{file}` | idem | **idem** | < 20 Mo, `image/*` | 🔴 |
| media/audio : update, delete | | interdits | les fichiers ne sont jamais supprimés : ni à la suppression d'un message, ni à celle d'un groupe, ni après un upload d'album partiel | 🟠 RGPD, coût |

Les URLs `getDownloadURL` portent un token permanent : toute personne qui détient l'URL lit le fichier, indépendamment des rules (S-16). Ces URLs sont stockées dans des documents que n'importe quel membre peut modifier (S-04, S-13).

### 10.3 Cloud Functions (`functions/src/index.ts`)

| Point | Constat |
|---|---|
| Surface | Uniquement des triggers Firestore (14). Aucun callable ni endpoint HTTP, donc pas de surface d'entrée directe ✅ |
| Authentification et validation | Les triggers font confiance au contenu des documents : `senderName`, `paidByName` et `creatorName` sont fournis par le client et repris tels quels dans les notifications (FN:141, 282, 458). Notifications usurpables (S-11) |
| Idempotence | Aucune. Les triggers sont *at-least-once*, des notifications en double sont possibles. `onGroupDeleted` est idempotent de fait |
| Effets de bord en cascade | La purge de `members` dans `onGroupDeleted` (FN:52-66) déclenche `onMemberRemoved` pour chaque membre : chacun reçoit en plus « Tu as été retiré du groupe » (G7). Quitter volontairement envoie aussi ce message à celui qui part (G8) |
| Purge incomplète | `config` (tabSettings) n'est pas supprimé (FN:52), pas plus que le Storage (`media`, `audio`, `group_photos`, `chat_backgrounds`). Rien ne réagit à la suppression d'un compte (G3) |
| Tokens FCM | Un seul `fcmToken` par utilisateur (pas de multi-appareil). Les réponses de `sendEachForMulticast` sont ignorées, donc les tokens invalides ne sont jamais nettoyés (FN:215-237) |
| Logique | `onEventUpdated` notifie à chaque update sans comparer avant/après (FN:288-302) ; les suppressions sont attribuées au créateur et non à l'auteur (FN:304-318, 360-374) |
| Qualité | 462 lignes dans un seul fichier, helpers dupliqués (récupération des tokens ×4), `console.log` au lieu de `logger`, région par défaut, aucun test ni lint, `node: 20` (fin de vie upstream en avril 2026 : vérifier le calendrier de dépréciation Cloud Functions), `firebase-functions ^6`, `firebase-admin ^12` |

### 10.4 Secrets, clés et configuration

| Point | Constat |
|---|---|
| Secrets dans le code | Aucun trouvé : pas de clé privée, de keystore ni de compte de service versionné. La CI utilise les secrets GitHub ✅ |
| Config Firebase | `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `macos/…plist` et `lib/firebase_options.dart` sont versionnés **alors qu'ils sont dans `.gitignore`** (ajoutés avant). Ce ne sont pas des secrets (ce sont des identifiants), mais **la sécurité repose alors entièrement sur les rules et App Check**, aujourd'hui inopérants. À recommander : restrictions d'API key par application dans la console GCP. Le workflow Android utilise le `google-services.json` versionné |
| Logs | Token FCM écrit dans logcat, y compris en release (`debugPrint`, NOTIF:80) |
| iOS | `aps-environment = development` dans `Runner.entitlements` : vérifier que la signature de distribution le remplace bien par `production` |

### 10.5 App Check, deep links et invitations

| Point | Constat |
|---|---|
| App Check | `FirebaseAppCheck.instance.activate(providerAndroid: AndroidDebugProvider())` sans condition (`main.dart:20-22`). En release, l'app envoie des tokens *debug* non enregistrés. Soit l'enforcement est désactivé dans la console (donc aucune protection), soit il est activé et les clients Android seraient rejetés. Le premier cas est le plus probable. Aucun provider Apple explicite. **À confirmer dans la console** |
| Codes d'invitation | 6 caractères parmi 32 (≈ 1,07 × 10⁹), générés par `Random()` non cryptographique (`shared/models/group.dart:28-32`), sans expiration, sans limite d'usage, sans limitation de débit. Brute-force réaliste à partir d'un grand nombre de groupes, et inutile de toute façon puisque `list` est autorisé (S-02). Aucun test de collision : un nouveau code peut écraser celui d'un autre groupe (GR:61-67, 230) |
| Révocation | Régénérer le code invalide l'ancien (GR:218-239). Mais un membre retiré connaît le `groupId` et peut se réajouter seul (S-09) |
| Lien `/i/CODE` | Le code est inséré via `textContent` (pas de XSS) mais n'est pas validé avant d'être injecté dans l'URL `intent://` (`hosting/public/invite.html:116-142`). Recommandé : `/^[A-Z0-9]{6}$/` |
| Lien App Store | Valeur factice `id0000000000` (`invite.html:112`) : les utilisateurs iOS sans l'app arrivent sur un lien cassé |
| App Links Android | `assetlinks.json` ne contient que les empreintes debug et upload. Sans celle de **Play App Signing**, la vérification échoue pour les installations depuis le Play Store (`hosting/README.md`). À vérifier |
| Côté app | `InviteLink.codeFromUri` (`core/constants/invite.dart:34-50`) normalise sans valider le format ; JL fait la résolution |

### 10.6 Preuve de concept (émulateur, rules actuelles)

Script hors dépôt (`@firebase/rules-unit-testing`, projet fictif `demo-zyncro`). Mallory et Eve sont des comptes **anonymes**, membres d'aucun groupe.

```
REFUSÉ    C1 non-membre lit le doc groupe (avant auto-ajout)
AUTORISÉ  F1 anonyme liste TOUS les invite_codes
AUTORISÉ  F2 anonyme crée son doc membre dans g1 (sans code)
AUTORISÉ  F3 … puis lit les messages de g1
AUTORISÉ  F3b … et les dépenses de g1
AUTORISÉ  F4 … se nomme propriétaire (createdBy) et vide memberIds
AUTORISÉ  F5 … modifie le message d'Alice (usurpation)
AUTORISÉ  F6 … supprime le groupe
AUTORISÉ  S1 anonyme non-membre liste media/g1/
AUTORISÉ  S2 anonyme non-membre télécharge un média de g1
AUTORISÉ  S3 anonyme écrase la photo du groupe g1
AUTORISÉ  S4 anonyme upload 1 fichier dans media/<groupe quelconque>
AUTORISÉ  S5 photo de profil sans contrôle de type
REFUSÉ    C2 lecture du doc users d'un autre
```

Vérifié ensuite : les rules déployées en production étaient **identiques** à celles de `main` (Firestore et Storage). Une sauvegarde a été faite avant le déploiement du correctif S1.

Chaîne d'attaque complète, sans compte ni code :
1. connexion anonyme ;
2. `list invite_codes`, qui donne tous les `groupId` ;
3. `create members/{moi}` dans chaque groupe ;
4. lecture complète des données de chaque groupe, et `listAll` + téléchargement des médias ;
5. optionnellement, prise de contrôle du groupe puis suppression.

---

## 11. Cloud Functions : structure

| Export (à conserver tel quel : renommer un export provoque une suppression puis une recréation au déploiement) | Trigger |
|---|---|
| `onGroupDeleted` | delete `groups/{gid}` |
| `onMemberRemoved` | delete `groups/{gid}/members/{uid}` |
| `onNewMessage`, `onMessageReaction` | create, update `messages` |
| `onNewExpense`, `onExpenseUpdated` | create, update `expenses` |
| `onEventCreated`, `onEventUpdated`, `onEventDeleted` | `events` |
| `onNoteCreated`, `onNoteUpdated`, `onNoteDeleted` | `notes` |

Découpage cible : PLAN §2.6 et étape 11.

## 12. Outillage et CI

| Point | Constat |
|---|---|
| `analysis_options.yaml` | `flutter_lints` seul, aucune règle ajoutée |
| CI | Deux workflows de déploiement (tags `v*`) : Android vers Play production, iOS vers TestFlight. Aucun workflow de PR (analyze, test, build). Flutter `3.x` flottant, ce qui rend les builds de production non reproductibles |
| Functions | Pas d'ESLint, pas de tests, `lib/` versionné, pas de `predeploy` |
| Rules | Aucun test émulateur dans le dépôt |
| Dépendances | `dependency_overrides: record_linux` en chemin local (`zyncro/packages/record_linux`), à documenter |
