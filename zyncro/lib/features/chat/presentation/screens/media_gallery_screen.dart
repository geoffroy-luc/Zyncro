import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/chat/presentation/screens/media_viewer_screen.dart';
import 'package:zyncro/features/chat/presentation/widgets/gallery_media_tile.dart';
import 'package:zyncro/features/chat/presentation/widgets/media_gallery_screen_helpers.dart';

class MediaGalleryScreen extends ConsumerWidget {
  const MediaGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaMessagesProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Médias partagés'),
        backgroundColor: Colors.white,
        foregroundColor: context.colors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.colors.border),
        ),
      ),
      body: mediaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (messages) {
          final items = galleryBuildItems(messages);
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: context.colors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun média partagé',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }
          // Liste plate avec métadonnées par item pour le viewer global
          final viewerItems = items
              .map(
                (item) => {
                  'url': item.url,
                  'mimeType': item.mimeType,
                  'senderName': item.message.senderName ?? '',
                  'sentAt': item.message.timestamp.millisecondsSinceEpoch,
                },
              )
              .toList();

          return GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => GalleryMediaTile(
              item: items[index],
              viewerItems: viewerItems,
              viewerIndex: index,
            ),
          );
        },
      ),
    );
  }
}

// ── Widget réutilisable pour l'aperçu dans le dashboard ──────────────────────

class MediaPreviewTile extends StatelessWidget {
  final Message message;
  const MediaPreviewTile({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(message.content) as Map<String, dynamic>;
    } catch (_) {
      return const SizedBox.shrink();
    }

    // Album multi-médias : on affiche le premier média
    if (data.containsKey('medias')) {
      final medias = (data['medias'] as List).cast<Map<String, dynamic>>();
      if (medias.isEmpty) return const SizedBox.shrink();
      final first = medias.first;
      final url = first['url'] as String? ?? '';
      final isVideo = (first['mimeType'] as String? ?? '').startsWith('video/');

      return GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AlbumSwipeViewer(
              medias: medias,
              initialIndex: 0,
              senderName: message.senderName,
              sentAt: message.timestamp,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: isVideo
                    ? Container(
                        color: context.colors.mediaBackground,
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: context.colors.border,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${medias.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Média seul
    final url = data['url'] as String? ?? '';
    final mimeType = (data['mimeType'] as String?) ?? '';
    final isVideo = mimeType.startsWith('video/');

    return GestureDetector(
      onTap: () {
        if (isVideo) {
          unawaited(
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => VideoViewerScreen(
                  url: url,
                  senderName: message.senderName,
                  sentAt: message.timestamp,
                ),
              ),
            ),
          );
        } else {
          unawaited(
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ImageViewerScreen(
                  url: url,
                  senderName: message.senderName,
                  sentAt: message.timestamp,
                ),
              ),
            ),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 72,
          height: 72,
          child: isVideo
              ? Container(
                  color: context.colors.mediaBackground,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: context.colors.border,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
