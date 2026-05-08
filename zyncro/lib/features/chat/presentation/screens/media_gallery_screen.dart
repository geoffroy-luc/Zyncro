import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/message.dart';
import '../providers/messages_provider.dart';
import 'media_viewer_screen.dart';

class MediaGalleryScreen extends ConsumerWidget {
  const MediaGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaMessagesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Médias partagés'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: mediaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (messages) {
          if (messages.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'Aucun média partagé',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: messages.length,
            itemBuilder: (context, index) =>
                _MediaTile(message: messages[index]),
          );
        },
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final Message message;
  const _MediaTile({required this.message});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(message.content) as Map<String, dynamic>;
    } catch (_) {
      return const SizedBox.shrink();
    }
    final url = data['url'] as String? ?? '';
    final mimeType = (data['mimeType'] as String?) ?? '';
    final isVideo = mimeType.startsWith('video/');

    return GestureDetector(
      onTap: () {
        if (isVideo) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => VideoViewerScreen(
              url: url,
              senderName: message.senderName,
              sentAt: message.timestamp,
            ),
          ));
        } else {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ImageViewerScreen(
              url: url,
              senderName: message.senderName,
              sentAt: message.timestamp,
            ),
          ));
        }
      },
      child: isVideo ? _VideoThumb(url: url) : _ImageThumb(url: url),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final String url;
  const _ImageThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.border,
        child: const Icon(Icons.broken_image_outlined,
            color: AppColors.textSecondary),
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  final String url;
  const _VideoThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1C1E),
      child: const Center(
        child: Icon(
          Icons.play_circle_fill_rounded,
          color: Colors.white,
          size: 36,
        ),
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
    final url = data['url'] as String? ?? '';
    final mimeType = (data['mimeType'] as String?) ?? '';
    final isVideo = mimeType.startsWith('video/');

    return GestureDetector(
      onTap: () {
        if (isVideo) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => VideoViewerScreen(
              url: url,
              senderName: message.senderName,
              sentAt: message.timestamp,
            ),
          ));
        } else {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ImageViewerScreen(
              url: url,
              senderName: message.senderName,
              sentAt: message.timestamp,
            ),
          ));
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 72,
          height: 72,
          child: isVideo
              ? Container(
                  color: const Color(0xFF1C1C1E),
                  child: const Center(
                    child: Icon(Icons.play_circle_fill_rounded,
                        color: Colors.white, size: 28),
                  ),
                )
              : Image.network(url, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.border,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.textSecondary),
                  )),
        ),
      ),
    );
  }
}
