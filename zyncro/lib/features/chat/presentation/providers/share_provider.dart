import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/invite.dart';
import '../../../../core/services/group_activity_service.dart';
import '../../../../core/services/share_shortcuts_service.dart';
import '../../../../shared/models/group.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';

// ── Contenu partagé en attente d'être envoyé ─────────────────────────────────

enum SharedKind { media, text }

class PendingShare {
  final SharedKind kind;
  final List<({String path, String mimeType})> medias;
  final String? text;

  /// Groupe choisi directement via un raccourci de partage direct (ou null).
  final String? preselectedGroupId;

  PendingShare.media({required this.medias, this.preselectedGroupId})
    : kind = SharedKind.media,
      text = null;

  PendingShare.text({required this.text, this.preselectedGroupId})
    : kind = SharedKind.text,
      medias = const [];
}

// ── Réception d'un partage entrant ───────────────────────────────────────────

/// Écoute les partages entrants (photos / vidéos / texte) et, quand il y en a
/// un, publie le [PendingShare] puis navigue vers l'écran « Partager vers… ».
class IncomingShareNotifier extends Notifier<PendingShare?> {
  StreamSubscription<List<SharedMediaFile>>? _sub;
  bool _initialHandled = false;

  @override
  PendingShare? build() {
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _onShared,
      onError: (_) {},
    );
    ref.onDispose(() => _sub?.cancel());

    // Démarrage à froid : traite l'intent initial une seule fois.
    if (!_initialHandled) {
      _initialHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final initial = await ReceiveSharingIntent.instance.getInitialMedia();
        if (initial.isNotEmpty) {
          await _onShared(initial);
          await ReceiveSharingIntent.instance.reset();
        }
      });
    }

    // Reprend un partage reçu hors-connexion dès que l'utilisateur se connecte.
    ref.listen(authStateProvider, (_, next) {
      if (next.asData?.value != null && state != null) {
        _navigate();
      }
    });

    return null;
  }

  Future<void> _onShared(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;
    final pending = await _toPending(files);
    if (pending == null) return;
    state = pending;
    final loggedIn = ref.read(authStateProvider).asData?.value != null;
    if (loggedIn) _navigate();
    // sinon : on attend la connexion (voir ref.listen dans build()).
  }

  Future<PendingShare?> _toPending(List<SharedMediaFile> files) async {
    bool isText(SharedMediaFile f) =>
        f.type == SharedMediaType.text || f.type == SharedMediaType.url;

    // Un lien d'invitation (schéma `zyncro://i/CODE` ou App Link
    // `https://…/i/CODE`) ouvert d'un clic arrive via un intent ACTION_VIEW.
    // receive_sharing_intent capte AUSSI cet intent et le présente comme un
    // « partage » de type URL, ce qui ouvrait à tort l'écran « Partager vers… »
    // par-dessus l'écran d'adhésion. On ignore donc ces liens ici : ils sont
    // pris en charge par inviteLinkProvider (app_links → /i/CODE).
    bool isInviteLink(SharedMediaFile f) {
      if (!isText(f)) return false;
      final uri = Uri.tryParse(f.path.trim());
      return uri != null && InviteLink.codeFromUri(uri) != null;
    }

    files = files.where((f) => !isInviteLink(f)).toList();
    if (files.isEmpty) return null;

    final groupId = await ShareShortcutsService.consumeShareTargetGroupId();

    // Partage 100 % texte / lien.
    if (files.every(isText)) {
      final text = files.map((f) => f.path).where((s) => s.isNotEmpty).join('\n');
      if (text.isEmpty) return null;
      return PendingShare.text(text: text, preselectedGroupId: groupId);
    }

    // Partage média (photos / vidéos), on ignore d'éventuels bouts de texte.
    final medias = <({String path, String mimeType})>[];
    for (final f in files) {
      if (isText(f)) continue;
      final mime =
          f.mimeType ??
          (f.type == SharedMediaType.video ? 'video/mp4' : 'image/jpeg');
      medias.add((path: f.path, mimeType: mime));
    }
    if (medias.isEmpty) return null;
    return PendingShare.media(medias: medias, preselectedGroupId: groupId);
  }

  void _navigate() {
    ref.read(routerProvider).push('/share');
  }

  /// Efface le partage en attente (après envoi ou annulation).
  void clear() => state = null;
}

final incomingShareProvider =
    NotifierProvider<IncomingShareNotifier, PendingShare?>(
      IncomingShareNotifier.new,
    );

// ── Raccourcis de partage direct (groupes les plus actifs) ───────────────────

/// Maintient les raccourcis « partage direct » Android synchronisés avec les
/// groupes les plus actifs de l'utilisateur.
class ShareShortcutsController extends Notifier<void> {
  final Map<String, Uint8List?> _iconCache = {};

  @override
  void build() {
    // Re-publie dès que la liste des groupes change (ajout, suppression, photo).
    ref.listen(userGroupsProvider, (_, next) {
      final groups = next.asData?.value;
      if (groups != null) _resync(groups);
    }, fireImmediately: true);
  }

  /// À appeler quand l'utilisateur interagit avec un groupe (ouverture, envoi).
  Future<void> recordInteraction(String groupId, {double weight = 1.0}) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    await GroupActivityService.recordInteraction(uid, groupId, weight: weight);
    final groups = ref.read(userGroupsProvider).asData?.value;
    if (groups != null) _resync(groups);
  }

  Future<void> _resync(List<Group> groups) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null || groups.isEmpty) {
      await ShareShortcutsService.clearAll();
      return;
    }
    final ranked = await GroupActivityService.rank(uid, groups);
    final top = ranked.take(4).toList();

    final shortcuts = <GroupShortcut>[];
    for (final g in top) {
      shortcuts.add(
        GroupShortcut(id: g.id, label: g.name, iconPng: await _iconFor(g)),
      );
    }
    await ShareShortcutsService.pushGroups(shortcuts);
  }

  Future<Uint8List?> _iconFor(Group g) async {
    final url = g.photoUrl;
    if (url == null || url.isEmpty) return null; // le natif dessinera l'initiale
    if (_iconCache.containsKey(url)) return _iconCache[url];
    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      final bytes = resp.statusCode == 200 ? resp.bodyBytes : null;
      _iconCache[url] = bytes;
      return bytes;
    } catch (_) {
      _iconCache[url] = null;
      return null;
    }
  }
}

final shareShortcutsControllerProvider =
    NotifierProvider<ShareShortcutsController, void>(
      ShareShortcutsController.new,
    );
