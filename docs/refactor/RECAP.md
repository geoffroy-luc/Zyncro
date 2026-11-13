# Récapitulatif du refactoring — Zyncro

> Point d'étape au 2026-11-12. Docs associées : [`AUDIT.md`](AUDIT.md), [`PLAN.md`](PLAN.md) (avancement par étape), [`BUGS_FOUND.md`](BUGS_FOUND.md), [`../ARCHITECTURE.md`](../ARCHITECTURE.md).

## 1. Branches et commits

Tout est fusionné **localement** dans `main` (rien n'est poussé : `origin/main` est encore sur l'état d'avant le refactor).

```
main
 ├─ merge fix/security-rules       rules Firestore/Storage durcies + firebase-tests/ (98 tests)
 ├─ merge fix/client-hotfixes      G1 réglages champ par champ, D1/D2 parsing tolérant, App Check
 ├─ merge refactor/architecture    ~35 commits [REFACTO]
 └─ merge fix/bugs                 corrections de bugs (BUGS_FOUND.md), un commit par lot
```

## 2. Ce qui est en production

| Quoi | État |
|---|---|
| Rules **Firestore** durcies (S1) | ✅ Déployées et vérifiées : version déployée = dépôt. Validées par 98 tests émulateur et par le test bout en bout de l'app réelle (0 refus de permission) |
| Rules **Storage** durcies (S1) | ✅ Déployées et vérifiées (= dépôt). Le rôle IAM `roles/firebaserules.firestoreServiceAgent` a été accordé par la CLI Firebase lors du déploiement |
| Cloud Functions | ✅ Redéployées en **Node 22** (le runtime Node 20 est décommissionné depuis le 2026-10-30). Code découpé par domaine, notifications strictement identiques (tests snapshot) |
| Callable `joinGroupByCode` (S3, phase 1) | ✅ Déployé le 2026-11-12, et appelé par le client de la release N. Déroulé des phases suivantes : `S3.md` |
| Cloud Functions (corrections G7, G8, F1, F2) | ✅ `onMemberRemoved`, `onEventDeleted`, `onNoteDeleted` passés aux triggers « WithAuthContext » (migration en place, exports inchangés) et `onEventUpdated` : déployées le 2026-11-12 |
| Index Firestore | ✅ Index composite `messages (type ASC, timestamp DESC)` déployé : aperçu médias du dashboard et galerie paginée |
| Sauvegarde des rules d'avant S1 | `/home/zoff/Dev/zyncro-tools/deployed-rules-backup/` (rollback possible) |

Le code client (App Check, G1, D1, refactor) doit encore être publié via une release. Les rules déployées acceptent la v1.1.3 actuelle comme la nouvelle version (tests de compatibilité).

## 3. Ce qui a changé

**Sécurité** (AUDIT §10). Plus d'auto-ajout avec un rôle, plus d'énumération des codes, plus de prise de contrôle d'un groupe, plus d'usurpation ni de modification des messages des autres. Les documents métier sont validés à l'écriture (mitige D1). App Check utilise de vrais providers en release, et le token FCM n'apparaît plus dans les logs.

**Architecture** (voir `ARCHITECTURE.md`) :
- **Domaine pur.** Entités par feature, sans Firestore. Les mappers (`XMapper` / `XFields`) produisent un format écrit **strictement identique** (36 assertions de caractérisation). Repositories `XRepository` / `FirestoreXRepository`, avec les instances Firebase injectées. Entité `AppUser` : le `User` Firebase ne sort plus de la couche data.
- **Règles d'architecture vérifiées par tests** : `domain/` pur, aucune instance Firebase hors `core/firebase`, `presentation/` sans Firestore ni Storage **ni plugin média / réseau**, `core/` sans dépendance vers les features. Le cycle router ↔ features ↔ services a disparu.
- **Services transverses** : `core/media` (sélecteur photo / vidéo, compression avant envoi, enregistrement dans la galerie, enregistreur vocal, téléchargement d'octets), `core/notifications` (plus de `WidgetRef` statique), `core/app_update` (logique pure testée), `core/error` (`Failure`), `core/logging`. Aperçus de liens dans un service du chat, testé.
- **Navigation** : `AppRoutes`, redirection pure testée, shell séparé, politique du bouton retour prête.
- **Design system** : `ZyncroColors` (ThemeExtension, valeurs historiques exactes) et `context.colors`, sur 454 usages ; couleurs d'identité (onglets, soldes) en `TabPalette` / `BalancePalette`. C'est le prérequis du mode sombre.
- **l10n** : gen-l10n, ARB français de 333 clés. Tous les `Text('…')` sont migrés (texte identique au caractère près, test de non-régression) ; un test interdit les nouveaux.
- **Découpage** : `chat_screen.dart` passe de 4 203 à 258 lignes. Le plus gros fichier fait désormais 514 lignes (882 au point précédent). Les longs `build` (chat, formulaire de dépense, calendrier, réglages d'accueil) sont découpés en widgets (`ChatSearchBar`, `ComposerContextBar`, `RecordingBar`, `GradientCircleButton`…) et en sections. Les visionneuses média ont un fichier par écran. Le code mort est supprimé.
- **Logique métier en services de domaine testés** : soldes, plan de remboursement, requêtes et filtres du calendrier, expansion des récurrences, codes d'invitation, pagination temps réel (`LiveWindowPager`), limitation de l'indicateur de frappe.
- **Cloud Functions** : un fichier par trigger, lecture typée des documents, ESLint strict, tests snapshot, Node 22.

**Qualité** :
- `flutter analyze` à **0 issue** avec `strict-casts`, `strict-inference`, `strict-raw-types` et environ 40 règles (point de départ : 24 infos, ou 726 avec ce jeu).
- Tests : 0 au départ, maintenant **163** côté Flutter (unitaires, caractérisation, architecture, l10n, repositories sur Firestore simulé), **43** côté functions et **98** côté rules, plus **1 test bout en bout** (app réelle sur émulateur Android, contre les émulateurs Firebase : invité, espace, note, événement, dépense, message, galerie, réglages de l'accueil).
- CI de PR ajoutée, Flutter épinglé, `node_modules` et `lib/` des functions retirés du dépôt.

**Performance** :
- Compteur de non-lus plafonné à 100, le badge « 99+ » reste identique.
- Aperçu médias du dashboard borné côté serveur : 6 documents au lieu de tout l'historique.
- **Galerie paginée** (D9) : les 60 médias les plus récents en temps réel, puis 60 par 60 au défilement. Auparavant, tout l'historique média était chargé et écouté. Limite assumée : une suppression dans les pages anciennes n'apparaît qu'à la réouverture (comme dans le chat).
- **Indicateur de frappe** : au plus une écriture Firestore toutes les 2 s pendant la saisie, au lieu d'une par frappe. L'affichage chez les autres membres est identique (seuil de lecture de 6 s, suppression 4 s après la dernière frappe).
- Aperçus de liens mis en cache en mémoire (succès seulement) : un lien n'est plus re-téléchargé à chaque réaffichage d'une bulle.

**Bugs corrigés** : 65 sur 99 (détail et restants dans `BUGS_FOUND.md`, en-tête). Les plus importants :
- **Chat** : messages qui disparaissaient après « charger plus » (C1), pagination bloquée (C3), médias cassés par « Modifier » (C5), état conservé d'un groupe à l'autre (C14), texte perdu si l'envoi échoue (C11), réactions comptées comme votes (C8).
- **Dépenses** : montants au centime près, soldes qui somment exactement à 0, y compris sur les données existantes (E1, E2, E3, E5) ; modifier ou supprimer une occurrence d'une série ne touche plus le passé (E8, E9) ; remboursements hors des totaux (E23).
- **Calendrier** : événements sur plusieurs mois (K1), occurrences de série et heure d'été (K2, CA3, E12), champs et couleur effaçables (CA1, CA2, K3), choix « celle-ci et les suivantes / toute la série » (K2, CA6).
- **Notifications** : plus de « Tu as été retiré du groupe » en quittant ou à la suppression du groupe (G7, G8), suppressions attribuées à leur auteur (F1).
- **Divers** : modifications concurrentes de notes conservées (G11), rejoindre un groupe déjà rejoint (G5), vidéos en erreur (M14), envois de fichiers (M1, M2), crashs de règles et de sélecteurs de date (E15, CA4).

Aucun nouveau champ en base : les correctifs n'utilisent que des champs existants (`until`, `count`…) ou des suppressions de clé, lisibles par les versions publiées.

## 4. Dette technique assumée

| Sujet | État | Suite proposée |
|---|---|---|
| Controllers d'écran | La logique des gros écrans reste dans des mixins de `State`, pas encore dans des controllers `Notifier` | `ChatComposerController`, `ExpenseFormController`…, un écran à la fois, avec widget tests |
| Taille des fichiers | 22 fichiers > 300 lignes (max 514 : éditeur de note, puis repository des messages 497, sélecteur de médias 480, profil 474) | Même méthode : widgets de composition et sections |
| l10n | Environ 120 chaînes hors `Text(...)` : validateurs, messages d'erreur, ternaires. Certaines sont des **données** écrites en base (`'Anonyme'` comme nom d'expéditeur, messages système), à ne pas traduire à l'aveugle | Migrer au cas par cas, en séparant texte d'interface et valeurs persistées |
| Couleurs et styles | 301 `Colors.*` (dont 170 `Colors.white`, 24 `transparent`), 35 littéraux restants (palettes de sélection de couleur, logo Google, constantes `AppColors`), 263 `TextStyle(` | `onPrimary` / `surface` selon le sens de chaque blanc, `AppTextStyles`, puis `ZyncroColors.dark` |
| Performance | Pas encore faits : `cacheWidth` des miniatures, cache disque des images (D4), `autoDispose` des controllers, `jsonDecode` encore dans les `build` des bulles | Mesurer avec DevTools avant / après |
| Système générique de réglages d'onglet, catégories partagées, rôles | **Points d'extension conçus** (PLAN §3), non implémentés : ce sont des features à venir | — |
| Goldens visuels | Remplacés par la caractérisation, l'égalité des tokens et le test bout en bout | Ajouter des goldens avant de toucher au rendu |
| Rules : un non-membre qui connaît un `groupId` peut encore s'ajouter comme simple membre | Callable en place (S3 phase 1) ; le chemin client reste ouvert pour les versions ≤ 1.1.3 | Phase 3 de `S3.md` après la hausse de `minimum_version` |
| Partage vers Zyncro sur iOS | Inexistant (pas de Share Extension) | Feature iOS dédiée |

## 5. Recommandations, par priorité

1. **Pousser `main`** et **publier une release** : elle apporte App Check en production, G1 et D1, et tout le refactor.
2. Configurer **App Check** dans la console : Play Integrity lié au Play Console, DeviceCheck. Surveiller les métriques avant tout enforcement.
3. **S3** : la phase 1 est prête (release N). Ensuite, hausse de `minimum_version` 2 à 4 semaines après la release, puis règles strictes et enforcement App Check (`S3.md`).
4. **Bugs restants** (`BUGS_FOUND.md`, en-tête) : ceux qui demandent un changement de schéma sont à planifier avec S3 (G17, E10, E11, E20, G2, CA11). G3 (suppression de compte complète) est le plus important des restants.
5. Poursuivre le refactor de présentation (dette §4) en même temps que les nouvelles features : chaque nouvel écran suit `ARCHITECTURE.md` §9.
6. Vérifier que `assetlinks.json` contient l'empreinte Play App Signing (l'id App Store est en place sur `invite.html`).

## 6. Vérifier les rules déployées

`/usr/bin/node /home/zoff/Dev/zyncro-tools/scripts/fetch-deployed-rules.cjs zyncro-f5fdd <dossier>` récupère, en lecture seule, les rules Firestore et Storage déployées (à comparer avec `diff` à celles du dépôt) et indique l'état du rôle IAM.

## 7. Outils locaux (hors dépôt)

Tous les outils sont dans `/home/zoff/Dev/zyncro-tools/` :
- `scripts/e2e.sh` : émulateurs Firebase + AVD Pixel_5 + test bout en bout (code de sortie = résultat du test) ;
- `scripts/fetch-deployed-rules.cjs` : rules déployées et état du rôle IAM, en lecture seule ;
- scripts de transformation utilisés pour le refactor : découpage d'écrans et de `State`, extraction de sections de `build` (`extract_build_sections.py`), migration des couleurs et des chaînes, `unawaited`, mappers.
