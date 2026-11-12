# Récapitulatif du refactoring — Zyncro

> Point d'étape au 2026-11-12. Docs associées : [`AUDIT.md`](AUDIT.md), [`PLAN.md`](PLAN.md) (avancement par étape), [`BUGS_FOUND.md`](BUGS_FOUND.md), [`../ARCHITECTURE.md`](../ARCHITECTURE.md).

## 1. Branches et commits

Les branches sont locales (non poussées) et **chaînées** : à fusionner dans cet ordre.

```
main
 └─ fix/security-rules      1 commit   rules Firestore/Storage durcies + firebase-tests/ (98 tests)
     └─ fix/client-hotfixes  3 commits  G1 réglages champ par champ, D1/D2 parsing tolérant, App Check
         └─ refactor/architecture  ~25 commits [REFACTO]
```

⚠️ **Ne redéployez pas les rules depuis `main`** tant que `fix/security-rules` n'y est pas fusionnée. Les rules Firestore en production sont celles de cette branche.

## 2. Ce qui est en production

| Quoi | État |
|---|---|
| Rules **Firestore** durcies (S1) | ✅ Déployées et vérifiées : version déployée = dépôt. Validées par 98 tests émulateur et par le test bout en bout de l'app réelle (0 refus de permission) |
| Rules **Storage** durcies (S1) | ⏸️ **Pas déployées** : elles exigent le rôle IAM `roles/firebaserules.firestoreServiceAgent` pour le compte de service Storage. L'attribution automatique a été refusée par le garde-fou de Claude Code. Voir §6 |
| Cloud Functions | ✅ Redéployées en **Node 22** (le runtime Node 20 est décommissionné depuis le 2026-10-30 : plus aucun déploiement n'était possible). Code découpé par domaine, notifications strictement identiques (tests snapshot) |
| Index Firestore | ✅ Index composite `messages (type, timestamp desc)` déployé, nécessaire à l'aperçu médias borné du dashboard |
| Sauvegarde des rules d'avant S1 | `/home/zoff/Dev/zyncro-tools/deployed-rules-backup/` (rollback possible) |

Le code client (App Check, G1, D1, refactor) doit encore être publié via une release.

## 3. Ce qui a changé

**Sécurité** (AUDIT §10). Plus d'auto-ajout avec un rôle, plus d'énumération des codes, plus de prise de contrôle d'un groupe, plus d'usurpation ni de modification des messages des autres. Les documents métier sont validés à l'écriture (mitige D1). App Check utilise de vrais providers en release, et le token FCM n'apparaît plus dans les logs.

**Architecture** (voir `ARCHITECTURE.md`) :
- **Domaine pur.** Entités par feature, sans Firestore. Les mappers (`XMapper` / `XFields`) produisent un format écrit **strictement identique** (36 assertions de caractérisation). Repositories `XRepository` / `FirestoreXRepository`, avec les instances Firebase injectées. Entité `AppUser` : le `User` Firebase ne sort plus de la couche data.
- **Règles d'architecture vérifiées par tests** : `domain/` pur, aucune instance Firebase hors `core/firebase`, `presentation/` sans Firestore ni Storage, `core/` sans dépendance vers les features. Le cycle router ↔ features ↔ services a disparu.
- **Services transverses** : `core/media`, `core/notifications` (plus de `WidgetRef` statique), `core/app_update` (logique pure testée), `core/error` (`Failure`), `core/logging`.
- **Navigation** : `AppRoutes`, redirection pure testée, shell séparé, politique du bouton retour prête.
- **Design system** : `ZyncroColors` (ThemeExtension, valeurs historiques exactes) et `context.colors`, sur 454 usages. C'est le prérequis du mode sombre.
- **l10n** : gen-l10n en place, ARB français, shell migré.
- **Découpage** : plus aucun fichier de 1 000 lignes. `chat_screen.dart` passe de 4 203 à 882 lignes, plus 15 widgets et 5 mixins. Les formulaires, le calendrier et les réglages sont découpés de la même façon. Le code mort est supprimé.
- **Logique métier en services de domaine testés** : soldes, plan de remboursement, requêtes et filtres du calendrier, expansion des récurrences, codes d'invitation.
- **Cloud Functions** : un fichier par trigger, lecture typée des documents, ESLint strict, tests snapshot, Node 22.

**Qualité** :
- `flutter analyze` à **0 issue** avec `strict-casts`, `strict-inference`, `strict-raw-types` et environ 40 règles (point de départ : 24 infos, ou 726 avec ce jeu).
- Tests : 0 au départ, maintenant **110** côté Flutter (unitaires, caractérisation, architecture, repositories sur Firestore simulé), **32** côté functions et **98** côté rules, plus **1 test bout en bout** (app réelle sur émulateur Android, contre les émulateurs Firebase).
- CI de PR ajoutée, Flutter épinglé, `node_modules` et `lib/` des functions retirés du dépôt.

**Performance** :
- Compteur de non-lus plafonné à 100, le badge « 99+ » reste identique.
- Aperçu médias du dashboard borné côté serveur : 6 documents au lieu de tout l'historique.

**Corrigés** (voie rapide validée) :
- **G1** : les réglages d'onglet ne s'écrasent plus entre membres.
- **D1** : un document malformé ne casse plus un onglet.
- **D2** : un horodatage serveur en attente ne fait plus planter.

Tous les autres bugs sont **conservés**, et figés par des tests `BUG …`.

## 4. Dette technique assumée

| Sujet | État | Suite proposée |
|---|---|---|
| `build` encore longs (chat 757, formulaire de dépense 606, calendrier ~490, réglages d'accueil ~440) ; 22 fichiers > 300 lignes | La logique reste dans les mixins de `State`, pas encore dans des controllers `Notifier` | Extraire des widgets de composition et des controllers (`ChatComposerController`, `ExpenseFormController`…), un écran à la fois, avec widget tests |
| l10n | Seul le shell est migré ; environ 600 chaînes restent en dur | Migrer écran par écran, en profitant de l'extraction des widgets |
| Couleurs et styles | 303 `Colors.*` (surtout blanc / transparent), 55 littéraux (gradients d'onglet, palettes), 263 `TextStyle(` | Tokens de gradient d'onglet, `AppTextStyles`, `ZyncroColors.dark` |
| Compression média | Encore dans les mixins du chat et l'écran de partage | `MediaService.prepare(policy)` dans `core/media` |
| Galerie médias | Non paginée (D9 validé, non fait) | `orderBy` + `limit` + scroll infini (l'index est déjà déployé) |
| Système générique de réglages d'onglet, catégories partagées, rôles | **Points d'extension conçus** (PLAN §3), non implémentés : ce sont des features à venir | — |
| Goldens visuels | Remplacés par la caractérisation, l'égalité des tokens et le test bout en bout | Ajouter des goldens avant de toucher au rendu |
| Rules : un non-membre qui connaît un `groupId` peut encore s'ajouter comme simple membre | Résiduel documenté (S3) | Callable `joinGroupByCode` + mise à jour forcée |
| Partage vers Zyncro sur iOS | Inexistant (pas de Share Extension) | Feature iOS dédiée |

## 5. Recommandations, par priorité

1. **Déployer les rules Storage** (§6). Les médias de tous les groupes restent lisibles par n'importe quel compte qui connaît un `groupId`.
2. **Fusionner** `fix/security-rules` puis `fix/client-hotfixes` dans `main`, et **publier une release**. Elle apporte App Check en production, G1 et D1.
3. Configurer **App Check** dans la console : Play Integrity lié au Play Console, DeviceCheck. Surveiller les métriques avant tout enforcement.
4. Planifier **S3** :
   - adhésion via callable ;
   - timestamps serveur pour les messages (corrige K4, l'ordre des messages) ;
   - enforcement App Check ;
   - hausse de `minimum_version`.
5. **Corriger les bugs** par priorité (PLAN étape 13), en inversant leur test `BUG …` :
   - K2 / E8 / E9 : édition d'une occurrence ;
   - E1 / E2 : arrondis des montants ;
   - C1 à C3 : pagination du chat ;
   - K1, K3 ;
   - G7 / G8 : notifications en double.
6. Poursuivre le refactor de présentation (dette §4) en même temps que les nouvelles features : chaque nouvel écran suit `ARCHITECTURE.md` §9.
7. Compléter `invite.html` avec l'id App Store, et `assetlinks.json` avec l'empreinte Play App Signing.

## 6. Action requise : rules Storage

Ces rules vérifient l'appartenance au groupe dans Firestore (rules cross-service). Le compte de service Storage a besoin d'un rôle IAM. Deux options :

- depuis un terminal **interactif**, à la racine du dépôt sur `fix/security-rules` :

  ```bash
  firebase deploy --only storage
  ```

  Répondre **Oui** à « Cloud Storage for Firebase needs an IAM Role to use cross-service rules. Grant the new role? ».
- ou accorder le rôle `roles/firebaserules.firestoreServiceAgent` à `service-1010364828673@gcp-sa-firebasestorage.iam.gserviceaccount.com` (console IAM ou gcloud), puis lancer `firebase deploy --only storage`.

Les tests (`cd firebase-tests && npm test`) couvrent déjà tous les flux Storage de l'app actuelle.

## 7. Outils locaux (hors dépôt)

Tous les outils sont dans `/home/zoff/Dev/zyncro-tools/` :
- `scripts/e2e.sh` : émulateurs Firebase + AVD Pixel_5 + test bout en bout ;
- `scripts/fetch-deployed-rules.cjs` : rules déployées et état du rôle IAM, en lecture seule ;
- scripts de transformation utilisés pour le refactor : découpage d'écrans et de `State`, migration des couleurs, `unawaited`, mappers.
