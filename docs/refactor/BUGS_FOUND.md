# Bugs trouvés — non corrigés

> Règle : pendant le refactor, **aucun de ces bugs n'est corrigé en douce**. Ils sont figés par des tests de caractérisation, nommés `bug_<ID>_…` et marqués `// BUG <ID>`, qui seront inversés quand le correctif sera validé.
> Les failles de sécurité (S-xx) sont dans [`AUDIT.md`](AUDIT.md) §10 et traitées à part (PLAN, étapes S1 à S3).
>
> Mêmes alias que l'AUDIT : chemins Dart relatifs à `zyncro/lib/`, FR = `firestore.rules`, FN = `functions/src/index.ts`.
>
> **Corrigés hors refactor** (branche `fix/client-hotfixes`, voie rapide validée) : G1, D1, D2.
>
> Gravité : 🔴 perte ou corruption de données / montant faux · 🟠 fonctionnalité cassée · 🟡 gêne ou incohérence.
>
> Colonnes : « Cause probable » situe le défaut dans le code ; « Correctif ou test » donne une idée de correction et, quand il existe, le test unitaire ou widget qui le détecterait.

## Bugs connus (signalés), causes racines

| ID | Bug | Cause probable | Correctif ou test |
|---|---|---|---|
| K1 🟠 | Événements sur plusieurs mois mal gérés | Le filtre du mois ne retient que les événements dont le mois de **début** est celui affiché : `_eventsForMonth` (CAL:198-201). La grille (CAL:525) et la liste (CAL:307) en dépendent. Un événement du 28/10 au 03/11 est donc absent de novembre, mais visible si l'on sélectionne le 02/11 (CAL:306 filtre `allEvents`). L'agenda groupe par jour de début (CAL:205-208). La carte n'affiche pas la date de fin (CAL:810, 908). S'y ajoute une dérive des récurrences mensuelles et annuelles : `DateTime(y, m+1, d)` réassigne `current` (RU:69, 79-82), d'où 31/01 → 03/03 → 03/04 | Test de chevauchement `start < finMois && (end ?? start) >= débutMois`. Test : `occurrencesInMonth([28/10→03/11], nov)` contient l'événement ; mensuel au 31/01 → 31/01, 28/02, 31/03, 30/04 |
| K2 🟠 | Les événements passés du mois ne s'affichent pas | Un événement **ponctuel** passé s'affiche bien (aucun filtre sur la date courante). Les causes touchent les **séries** : (1) éditer une occurrence réécrit l'ancre de la série. Les instances gardent `base.id` (RU:52) avec `startDate: occurrence` (RU:56) ; le formulaire s'initialise sur l'instance (EVF:52-53) puis fait `update` (`events_repository.dart:59`). Toutes les occurrences antérieures disparaissent et `count` repart de zéro. (2) Les instances perdent `participantIds` (RU:51-65), donc le filtre participants masque toute la série. (3) `until` est enregistré à minuit et comparé par `isAfter` (EVF:409-420, RU:42-43) : le dernier jour est exclu. (4) Plafond de 1000 occurrences compté depuis l'ancre (RU:36-38, 68). (5) Le dashboard utilise `eventsProvider` non étendu (DB:75) | Entité d'occurrence `{seriesId, occurrenceStart}`. L'édition applique un delta à l'ancre ou propose « cette occurrence / toute la série ». Test : éditer l'occurrence du 16/11 d'une série hebdomadaire ancrée au 02/11 laisse l'ancre au 02/11 |
| K3 🟠 | Supprimer la couleur lors de l'ajout d'un événement ne marche pas | Deux causes. **(a) Navigator :** l'appui long sur une couleur ouvre un dialog avec `builder: (_)` puis `Navigator.pop(context)`, où `context` est celui de la `ColorPickerRow` (CPR:351, 358, 362). Le dialog est sur le navigator **racine**, alors que le formulaire est poussé dans le navigator **de branche** de la `StatefulShellRoute` (RT:128, CAL:319-323). Le `pop` ferme donc le **formulaire** (saisie perdue), le dialog reste ouvert et `onDeleteColor` n'est jamais appelé. Dans les écrans de réglages (navigator racine), le même code fonctionne. NoteEditor est touché aussi. **(b) Modèle :** en édition, impossible de retirer la couleur. `copyWith` fait `color ?? this.color` (`shared/models/event.dart:101`), `toMap` omet la clé si elle est nulle (`event.dart:71`), et `update()` fusionne (`events_repository.dart:59`). L'UI n'offre d'ailleurs aucun moyen de désélectionner une couleur (CPR:330, 385) | (a) `builder: (dialogCtx)` + `pop(dialogCtx)`. Widget test : navigator imbriqué, appui long puis « Supprimer » appelle `onDeleteColor` et la page reste affichée. (b) Drapeaux `clearX` dans `copyWith` + `toUpdateMap()` qui envoie `FieldValue.delete()` |
| K4 🟠 | Les messages d'un utilisateur s'affichent en dernier sans raison | `timestamp: DateTime.now()` vient de l'**horloge du téléphone** (MR:134, 176, 212, 252, 302, 332 ; `shared/models/message.dart:62`). Le tri est `orderBy('timestamp')` (MR:22, 40) et les rules n'imposent pas `request.time` (FR:89-91). Si l'horloge d'un utilisateur est en avance, ses messages restent en bas. Si elle est en retard, ils remontent dans l'historique, voire sortent de la fenêtre live. Effets secondaires : `markAsRead` peut stocker une date future (CHAT:1229), ce qui fausse les non-lus | `FieldValue.serverTimestamp()` + lecture avec `ServerTimestampBehavior.estimate`, `fromMap` tolérant au null, rule `timestamp == request.time`. Demande une mise à jour forcée (PLAN, étape S3) |

## Chat

| ID | Bug | Cause probable / fichier |
|---|---|---|
| C1 🔴 ✅ | Messages qui disparaissent après « charger plus » | Après un `loadMore`, chaque nouveau message pousse le plus ancien hors de la fenêtre live de 50 messages. Ce message n'est alors ni dans `_live` ni dans `_older` (MPV:61-69, 86-96, 110-114) |
| C2 🟠 | Anciens messages figés | `_older` est chargé par un `get()` unique : réactions, votes, éditions et suppressions au-delà des 50 derniers ne sont jamais reflétées (MPV:110-114) |
| C3 🟠 ✅ | Pagination bloquée | `_hasMore = false` dès qu'il y a moins de 50 messages, et jamais remis à `true` (MPV:64) |
| C4 🟡 | Messages sautés | Curseur `isLessThan` : les messages de la même milliseconde sont ignorés (MR:41) |
| C5 🔴 ✅ | « Modifier » sur image, vidéo ou album casse le média | Le JSON est copié dans le champ texte puis écrasé par `editMessage` (CHAT:378-385) |
| C6 🟠 ✅ | « Télécharger » sur un album ne fait rien | `data['url']` est absent et l'erreur est avalée (CHAT:466-467, 473) |
| C7 🟡 ✅ | Mauvais libellé dans la citation de réponse | « Sondage » pour toute citation JSON, « Photo / Vidéo » pour un texte commençant par http (CHAT:3136-3140). Incohérent avec CHAT:1644-1652 |
| C8 🟠 ✅ | Les réactions emoji sur un sondage comptent comme des votes | Elles sont comptées comme votes (CHAT:333-363, 3606-3608) et effacées par un vote exclusif (CHAT:590) |
| C9 🟡 | « Répondre » proposé sur un sondage mais sans effet visible | `_PollCard` n'affiche pas de citation, et le swipe est désactivé (CHAT:367, 1476) |
| C10 🟠 ✅ | Réponse perdue | `sendAudio` et `sendPoll` ne transmettent pas la réponse, et la barre de réponse reste affichée (CHAT:605-618, 694-706) |
| C11 🟠 ✅ | Texte perdu si l'envoi échoue | Le champ est vidé avant l'`await`, sans `catch` ni retour à l'utilisateur (CHAT:252, 256-281) |
| C12 🟡 ✅ | Recherche sans résultat | Affiche « Aucun message. Soyez le premier ! » (CHAT:1392-1398) |
| C13 🟠 ✅ | Crash du build | Couleur hex invalide dans le fond du chat : `int.parse` sans garde (CHAT:1295) |
| C14 🔴 ✅ | État conservé au changement de groupe | Réponse, édition et recherche survivent au changement de groupe (`StatefulShellBranch`, RT:162). Conséquences : `replyToId` pointant vers un autre groupe, `editMessage` avec le mauvais `groupId` (CHAT:156) |
| C15 🟡 ✅ | Double timer d'enregistrement | Second `Timer.periodic` si l'enregistrement est relancé (CHAT:655) |
| C16 🟡 | Compteur de non-lus faux | Compte aussi ses propres messages et vaut 0 si `lastReadAt` est null (MPV:174-185) |
| C17 🟡 | `watchUnreadCount` (mort) ne se mettrait jamais à jour | `asyncExpand` met en pause le flux externe (MR:407) |
| C18 🟡 ✅ | Aperçu de lien périmé après édition du message | Pas de `didUpdateWidget` (CHAT:2474+, 2697+, 3314+) |

## Médias et partage

| ID | Bug | Cause probable / fichier |
|---|---|---|
| M1 🟠 | Upload refusé | Extension calculée par `split('.').last` : un chemin sans extension mais avec un dossier pointé produit un chemin invalide (MR:229, 275) |
| M2 🟠 | MIME erroné | Une image non compressée part en `image/jpeg` (STG:238) ; les GIF sont convertis en JPEG ; `SharedMediaType.file` est traité comme un média (SP:116-121) |
| M3 🟡 | Présélection Direct Share perdue au démarrage à froid | `_initialised = true` alors que la liste des groupes est encore vide (STG:36-42) |
| M4 🟡 | ID de raccourci appliqué au mauvais partage | Il n'est pas consommé quand le partage est un lien d'invitation (SP:103 vs 105) |
| M5 🟡 | Deux partages successifs à chaud | Deux écrans `/share` s'empilent (SP:127-129) |
| M6 🟡 | Démarrage à froid déconnecté : ordre non garanti | `push('/share')` et le redirect login → groups partent du même événement (SP:67-71, RT:62-66). À tester |
| M7 🟡 | Envoi en double possible | Échec après un envoi réussi : « Échec du partage » s'affiche quand même (STG:200-215) |
| M8 🟡 | Écran vide sans AppBar si `share == null` | (STG:45-50) |
| M9 🟠 | Fichiers orphelins dans Storage | Album partiellement uploadé, ancien fond de chat jamais supprimé. `delete: if false` (SR:32), CSET:184 |
| M10 🟡 | Réglages du chat | Pas de loader au premier choix d'image, `_update` non awaited, `settings` capturés au build (CSET:147-152, 221-245) |
| M11 🟡 | Téléchargement avec une URL vide | Exception brute affichée (MV:526, 911) |
| M12 🟡 | Clé dupliquée si la même vidéo apparaît deux fois | `ValueKey(url)` (MV:558, 939) |
| M13 🟡 | Accès limité Android : liste non rechargée | Rien ne recharge au retour des réglages (MP:130) |
| M14 🟠 | Vidéo en erreur : spinner infini, aucun bouton retour | `initialize()` sans `catchError`, bouton retour conditionné à l'init (MV:247, 315, 723) |
| M15 🟠 | Picker bloqué après une exception | Les drapeaux de chargement restent à true (MP:56-159) |
| M16 🟡 | Fichiers temporaires jamais supprimés | (MV:21, 44 ; STG:229 ; CHAT:644, 756, 853) |
| M17 🟡 | Durées affichées sans les heures | 1h05 s'affiche « 05:00 » (MV:284, 757 ; MP:161) |

## Dépenses

| ID | Bug | Cause probable / fichier |
|---|---|---|
| E1 🔴 | Valeurs par défaut du mode « Par montant » refusées sans saisie | Arrondi : 100 €/3 → 33,33×3 = 99,99, écart > 0,01 (EXF:144-151, 182) |
| E2 🔴 | Les soldes ne somment pas à zéro | Les % ne sont pas normalisés : 70 €/7 donne Σ = 70,021 (EXF:206, EXP:36-40) |
| E3 🟠 | Réenregistrer sans rien toucher change les montants | Le % n'est pas stocké, il est recalculé et arrondi (EXF:607-608) |
| E4 🟡 | Mode égal : écart stocké/affiché | Stocke 3,333…, affiche 3,33 (EXF:166, 961) |
| E5 🟠 | Résidus d'arrondi visibles | Carte rouge « -0,00 € » alors que les comptes sont équilibrés (EXS:414, 443, 462, 634 ; RF:43-44) |
| E6 🟡 | La répartition personnalisée est réinitialisée | Au changement de montant ; chaque frappe écrase les autres membres (EXF:120-136, 673-679) |
| E7 🟡 | Soldes et dettes abrégés en k/M | Imprécis pour de l'argent (EXS:41-44) |
| E8 🔴 | Éditer une instance récurrente modifie toute la série | Elle est rétro-datée (`expense.dart:126`, ER:67, EXF:55, 466) |
| E9 🔴 | Supprimer une instance supprime toute la série | Sans avertissement (EXF:541) |
| E10 🟠 | `settled` partagé par toutes les instances | (RU:123) |
| E11 🟡 | IDs d'instance instables | `${base.id}_$idx` (RU:115), bloquant pour lier une dépense à un événement |
| E12 🟠 | Dérive des dates de récurrence | Mensuel (31/01 → 03/03) et heure d'été (`add(Duration)`) (RU:77-80) |
| E13 🟡 | Occurrences manquantes | `now` est figé au snapshot ; plafond silencieux de 500 (RU:89, 107) |
| E14 🟡 | `until` exclut le jour même ; assertion du date picker | `initialDate < firstDate` (RU:111 ; EXF:329-330) |
| E15 🟠 | Crash sur une règle incohérente | `count!`, `until!` (RU:110-111, `recurrence_rule.dart:50`) |
| E16 🟠 | Pas d'état chargement ni erreur | Affiche 0,00 € ou « Aucune dépense » (EXS:128-139) |
| E17 🟡 | Impossible de retirer une catégorie | `copyWith` (`expense.dart:134, 140` ; EXF:1054) |
| E18 🟠 | Membres partis | Nom affiché comme un uid tronqué ; « Rembourser » produit un message avec un nom vide ; leur part est retirée silencieusement à l'édition (EXS:393 ; RF:113 ; EXF:160) |
| E19 🟡 | Devise cosmétique | « € » en dur (EXF:668-669, 685, 961, 989 ; RF:170 ; DB:55-57) ; yen affiché avec 2 décimales (EXS:48) |
| E20 🟠 | Catégories référencées par leur nom | Renommer ou supprimer les fait passer en gris ; doublons acceptés (`expense.dart:20` ; `expenses_settings_screen.dart:50-64` ; `category_editor_sheet.dart:56-63`) |
| E21 🟡 | Filtre de recherche fantôme après changement d'onglet | Le champ revient vide mais la liste reste filtrée (EXS:196, 214) |
| E22 🟡 | « Aujourd'hui » calculé sur des tranches de 24 h | (EXS:53-57) |
| E23 🟡 | Totaux incluant remboursements et dépenses réglées | Recevoir un remboursement augmente « Votre part » (EXS:143-149 ; DB:99-100) |
| E24 🟡 | Messages et limites incohérents | Toute erreur de suppression affiche « Permission refusée » (EXF:556) ; le nom vient de `user.displayName` et non du pseudo de membre (EXF:542) ; RF n'a pas de limite (RF:157-181) |
| E25 🟡 | Badge remboursement | Fond bleu, texte vert (EXS:833-841) |

## Calendrier

| ID | Bug | Cause probable / fichier |
|---|---|---|
| CA1 🟠 | Impossible de vider description, lieu ou heure de fin en édition | (`event.dart:94-97` ; EVF:178-199) |
| CA2 🟠 | Impossible de retirer une répétition en édition | `clearRecurrence` en mémoire, puis la clé est omise dans `toMap` (`event.dart:103, 73`) |
| CA3 🟠 | Heure d'été | Une série hebdomadaire à 9h passe à 8h (RU:77-78). Pas de notion de journée entière |
| CA4 🟡 | Bornes des pickers | `lastDate: DateTime(2030)` (EVF:91-92) ; `initialDate < firstDate` (EVF:411-412) ; heure de fin = 24 si début à 23h (EVF:61, 69) |
| CA5 🟠 | Rappels | Une seule notification sur la première occurrence (`reminder_service.dart:58-60`). Stockés par appareil, jamais replanifiés si un autre membre modifie l'événement. Préférences non nettoyées (93-95). ID dérivé de `hashCode` (21). Course de `_loadReminder` (EVF:63, 216). Doublon d'événement si `zonedSchedule` lève après `createEvent` (`reminder_service.dart:86` ; EVF:244-248). « 90 min » s'affiche « 1 heures » (EVF:529) |
| CA6 🟡 | Suppression | Toujours la série entière ; toute erreur affiche « Permission refusée » (EVF:148, 160-165) |
| CA7 🟡 | Mode agenda | L'agenda conserve le jour sélectionné (CAL:305-307, 449-456) |
| CA8 🟡 | Aujourd'hui sélectionné illisible | Texte blanc sur fond clair (CAL:534-544 vs 571-575) |
| CA9 🟡 | Créateur jamais affiché | `creatorName` n'est jamais écrit (`events_repository.dart:39-52`), les lignes correspondantes sont mortes (CAL:830, 926) |
| CA10 🟡 | Tri de la liste du provider en place | `allEvents..sort` (DB:86-87) |
| CA11 🟡 | `calendarFilters` partagés et inutilisés | Stockés dans le doc partagé du groupe (TS:63) mais jamais utilisés, les filtres restant locaux (CAL:48-49) |

## Groupes, réglages, notes, auth, dashboard

| ID | Bug | Cause probable / fichier |
|---|---|---|
| G1 🔴 ✅ | Perte de mises à jour des réglages d'onglet, réinitialisation possible de tous les onglets | `updateSettings` réécrit tout `TabSettings` (TSR:24-26) à partir d'un instantané. Avec le repli `?? TabSettings.defaults` (HS:521 ; `notes_settings_screen.dart:21` ; NE:244, 254 ; CSET:89), une écriture pendant le chargement remet catégories, fond, filtres et couleurs à leurs valeurs par défaut |
| G2 🟠 | Masquer une couleur dans les notes la masque partout | `customColors` et `hiddenBaseColors` sont globaux à toutes les palettes (TS:46-47, 212-219 ; CPR:373). `hiddenBaseColors` n'est pas dédoublonné (TS:218) |
| G3 🔴 | Suppression de compte | Ne supprime que l'utilisateur Auth (`auth_repository.dart:89-93`) : `memberIds`, docs membres, `users/{uid}` et photos restent. Les groupes possédés deviennent impossibles à administrer (FR:14-17, 73, 84). `requires-recent-login` est affiché brut (PR:270-279) |
| G4 🟠 | Déconnexion d'un compte invité (anonyme) | Le compte est perdu définitivement, sans avertissement (PR:244-246) |
| G5 🟠 | Rejoindre un groupe dont on est déjà membre | `set` sans merge : `role` repasse à member et le pseudo est réinitialisé (GR:86-95). Unicité du pseudo non contrôlée au join ; contrôle non transactionnel ailleurs (GR:279-288) |
| G6 🟠 | Codes d'invitation | Régénération sans transaction (GR:218-239) ; aucun test de collision (`group.dart:28-32`) : en cas de collision, la création du groupe **échoue** (les rules n'autorisent pas l'`update` d'un code existant, vérifié sur émulateur) au lieu d'écraser l'autre code ; nom et emoji non répercutés dans `invite_codes` (GR:206-215 ; HS:139-142) |
| G7 🟠 | Suppression de groupe | La purge de `members` déclenche `onMemberRemoved` : chaque membre reçoit en plus « Tu as été retiré du groupe » (FN:52-66, 71-104). `config` n'est pas purgé (FN:52), le Storage non plus |
| G8 🟠 | Quitter un groupe | Celui qui part reçoit « Tu as été retiré du groupe » (FN:71-104 + GR:155-179) |
| G9 🟡 | Spinner infini sur `/settings/*` après suppression du groupe ou retrait | La redirection ne couvre que le shell (GP:51-57 ; RT:72-79 ; HS:525-527) |
| G10 🟠 | Bouton retour Android | Ferme l'app depuis un onglet : aucun `PopScope`, uniquement des `go` (RT ; GSEL:50 ; JL:46). Feature à venir, à ne pas corriger pendant le refactor |
| G11 🟠 | Perte de mise à jour des notes | `copyWith` sur l'instantané d'ouverture puis `update(toMap())` complet (NE:153-164 ; `notes_repository.dart:62-64`). Épingler modifie `updatedAt` côté client (`note.dart:104`) |
| G12 🟡 | Dashboard | Événements récurrents absents (DB:75) ; événements multi-jours en cours exclus (DB:88-89) ; total incluant les remboursements (DB:99-100) ; « € » en dur (DB:55-57) |
| G13 🟡 | Interrupteur de notifications | Préférence locale non scopée par uid ; token réenregistré à chaque démarrage (PR:192 ; NOTIF:78-81) |
| G14 🟡 | Divers | Pseudo de profil non validé ; emoji `maxLength: 2` alors que la création propose des emojis composés (HS:116 vs GSEL:433) ; couleur ajoutée non visible (`category_editor_sheet.dart:158`) |
| G15 🟡 | `Image.network` sans `errorBuilder` | (HS:588, GSEL:253, RT:339) |
| G16 🟡 | Listener de tap sur notification en double | Si `initialize()` est rappelé sans logout (NOTIF:66-68, 102) |
| G17 🟠 | Un seul token FCM par utilisateur | Se déconnecter sur un appareil coupe les notifications des autres (NOTIF:142-145, 175) |
| G18 🟡 | Sélectionner un groupe efface les notifications de tous les groupes | (`app/app.dart:107-110`). À confirmer côté produit |

## Cloud Functions

| ID | Bug | Cause probable / fichier |
|---|---|---|
| F1 🟡 | Suppression d'événement ou de note mal attribuée | Attribuée au créateur et non à l'auteur ; l'auteur est notifié aussi (FN:304-318, 360-374) |
| F2 🟡 | `onEventUpdated` notifie même sans changement réel | (FN:288-302) |
| F3 🟡 | Tokens FCM invalides jamais nettoyés | (FN:215-237) |
| F4 🟡 | Notifications en double possibles | Triggers *at-least-once* sans idempotence |

## Robustesse des données

| ID | Bug | Cause probable / fichier |
|---|---|---|
| D1 🔴 ✅ | Un document malformé casse tout le stream pour tous les membres | Casts stricts et `values.byName` dans tous les `fromMap` (`shared/models/*.dart`). Une nouvelle valeur d'enum casserait les anciennes versions |
| D2 🟠 ✅ | Crash latent sur timestamp en attente | `Message.fromMap` plante sur un `timestamp` null (`message.dart:42`). C'est déjà possible pour le message système de `leaveGroup` (`serverTimestamp`, GR:174) dans le cache local de l'émetteur |
