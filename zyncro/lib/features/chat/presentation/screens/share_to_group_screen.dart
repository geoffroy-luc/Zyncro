import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/group.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../providers/messages_provider.dart';
import '../providers/share_provider.dart';

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
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: _sending ? null : _cancel,
        ),
        title: const Text(
          'Partager vers…',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _SharePreview(share: share),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: groups.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Vous n'avez encore aucun groupe.\nCréez-en un pour pouvoir partager.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: groups.length,
                    itemBuilder: (context, i) {
                      final g = groups[i];
                      return _GroupRow(
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
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
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
      context.go('/groups');
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
      context.go('/chat');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec du partage : $e')),
      );
    }
  }

  /// Compresse les images (comme dans le chat) ; laisse les vidéos telles quelles.
  Future<List<({String filePath, String mimeType})>> _compress(
    List<({String path, String mimeType})> medias,
  ) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return Future.wait(
      medias.asMap().entries.map((e) async {
        final index = e.key;
        final m = e.value;
        if (m.mimeType.startsWith('image/')) {
          final targetPath = '${dir.path}/share_${ts}_$index.jpg';
          final result = await FlutterImageCompress.compressAndGetFile(
            m.path,
            targetPath,
            quality: 85,
            minWidth: 1920,
            minHeight: 1920,
            keepExif: false,
          );
          return (filePath: result?.path ?? m.path, mimeType: 'image/jpeg');
        }
        return (filePath: m.path, mimeType: m.mimeType);
      }),
    );
  }
}

// ── Aperçu du contenu partagé ────────────────────────────────────────────────

class _SharePreview extends StatelessWidget {
  final PendingShare share;
  const _SharePreview({required this.share});

  @override
  Widget build(BuildContext context) {
    if (share.kind == SharedKind.text) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: AppColors.surface,
        child: Text(
          share.text ?? '',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: share.medias.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final m = share.medias[i];
            final isImage = m.mimeType.startsWith('image/');
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 88,
                height: 88,
                child: isImage
                    ? Image.file(File(m.path), fit: BoxFit.cover)
                    : Container(
                        color: Colors.black12,
                        child: const Icon(
                          Icons.play_circle_outline,
                          size: 34,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Ligne de groupe ──────────────────────────────────────────────────────────

class _GroupRow extends StatelessWidget {
  final Group group;
  final bool selected;
  final VoidCallback? onTap;

  const _GroupRow({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: selected
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: group.photoUrl != null
                  ? Image.network(group.photoUrl!, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        group.emoji?.isNotEmpty == true
                            ? group.emoji!
                            : (group.name.isNotEmpty
                                  ? group.name[0].toUpperCase()
                                  : '?'),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                group.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }
}
