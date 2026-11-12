import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zyncro/core/media/media_providers.dart';
import 'package:zyncro/core/navigation/app_routes.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/chat/presentation/providers/share_provider.dart';
import 'package:zyncro/features/chat/presentation/widgets/group_row.dart';
import 'package:zyncro/features/chat/presentation/widgets/share_preview.dart';
import 'package:zyncro/features/groups/domain/entities/group.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';

/// Écran présenté quand du contenu est partagé vers Zyncro depuis une autre app.
/// Affiche un aperçu, laisse choisir le groupe destinataire puis envoie.
class ShareToGroupScreen extends ConsumerStatefulWidget {
  const ShareToGroupScreen({super.key});

  @override
  ConsumerState<ShareToGroupScreen> createState() => _ShareToGroupScreenState();
}

class _ShareToGroupScreenState extends ConsumerState<ShareToGroupScreen> {
  String? _selectedGroupId;
  bool _sending = false;
  bool _initialised = false;

  @override
  Widget build(BuildContext context) {
    final share = ref.watch(incomingShareProvider);
    final groups = ref.watch(orderedGroupsProvider);

    // Pré-sélectionne le groupe choisi via le partage direct (une seule fois).
    if (!_initialised) {
      _initialised = true;
      final pre = share?.preselectedGroupId;
      if (pre != null && groups.any((g) => g.id == pre)) {
        _selectedGroupId = pre;
      }
    }

    // Plus rien à partager (déjà envoyé / annulé) → on ferme proprement.
    if (share == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: const SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        surfaceTintColor: context.colors.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.colors.textPrimary),
          onPressed: _sending ? null : _cancel,
        ),
        title: Text(
          context.l10n.chatPartagerVers,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          SharePreview(share: share),
          Divider(height: 1, color: context.colors.border),
          Expanded(
            child: groups.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.l10n.chatVousNAvezEncoreAucun,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: groups.length,
                    itemBuilder: (context, i) {
                      final g = groups[i];
                      return GroupRow(
                        group: g,
                        selected: g.id == _selectedGroupId,
                        onTap: _sending
                            ? null
                            : () => setState(() => _selectedGroupId = g.id),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildSendBar(groups),
    );
  }

  Widget _buildSendBar(List<Group> groups) {
    final canSend = _selectedGroupId != null && !_sending;
    final target = _selectedGroupId == null
        ? null
        : groups.where((g) => g.id == _selectedGroupId).firstOrNull;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: canSend ? _send : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.primary,
            disabledBackgroundColor: context.colors.primary.withValues(
              alpha: 0.4,
            ),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _sending
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  target == null
                      ? 'Choisir un groupe'
                      : 'Envoyer à ${target.name}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  void _cancel() {
    ref.read(incomingShareProvider.notifier).clear();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.groups);
    }
  }

  Future<void> _send() async {
    final groupId = _selectedGroupId;
    final share = ref.read(incomingShareProvider);
    final user = ref.read(authStateProvider).asData?.value;
    if (groupId == null || share == null || user == null) return;

    setState(() => _sending = true);

    final senderName = user.displayName ?? user.email ?? 'Anonyme';
    final repo = ref.read(messagesRepositoryProvider);

    try {
      if (share.kind == SharedKind.text) {
        await repo.sendMessage(
          groupId: groupId,
          senderId: user.uid,
          senderName: senderName,
          content: share.text ?? '',
        );
      } else {
        final compressed = await _compress(share.medias);
        if (compressed.length == 1) {
          await repo.sendMedia(
            groupId: groupId,
            senderId: user.uid,
            senderName: senderName,
            filePath: compressed.first.filePath,
            mimeType: compressed.first.mimeType,
          );
        } else {
          await repo.sendMultipleMedia(
            groupId: groupId,
            senderId: user.uid,
            senderName: senderName,
            medias: compressed,
          );
        }
      }

      // Monte le score d'activité + met à jour les raccourcis de partage direct.
      await ref
          .read(shareShortcutsControllerProvider.notifier)
          .recordInteraction(groupId, weight: 2.0);

      ref.read(incomingShareProvider.notifier).clear();
      await ref.read(selectedGroupIdProvider.notifier).select(groupId);

      if (!mounted) return;
      context.go(AppRoutes.chat);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatEchecDuPartage(e))),
      );
    }
  }

  /// Compresse les images (comme dans le chat) ; laisse les vidéos telles quelles.
  Future<List<({String filePath, String mimeType})>> _compress(
    List<({String path, String mimeType})> medias,
  ) =>
      ref.read(mediaPreparerProvider).prepareBatch(medias, filePrefix: 'share');
}
