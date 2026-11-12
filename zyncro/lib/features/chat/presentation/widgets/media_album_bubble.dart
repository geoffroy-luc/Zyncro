import 'package:flutter/material.dart';
import 'package:zyncro/features/chat/presentation/screens/album_swipe_viewer.dart';

// ── Album multi-médias style Instagram ───────────────────────────────────────
class MediaAlbumBubble extends StatelessWidget {
  final List<Map<String, dynamic>> medias;
  final bool isMe;
  final String? senderName;
  final DateTime sentAt;

  const MediaAlbumBubble({
    super.key,
    required this.medias,
    required this.isMe,
    this.senderName,
    required this.sentAt,
  });

  static const double _w = 220;
  static const double _h = 165;

  Widget _topThumbnail(BuildContext context) {
    final item = medias.first;
    final url = item['url'] as String? ?? '';
    final mimeType = (item['mimeType'] as String?) ?? '';
    if (mimeType.startsWith('video/')) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black87),
          const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white70,
              size: 48,
            ),
          ),
        ],
      );
    }
    return Image.network(
      url,
      width: _w,
      height: _h,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                    : null,
                color: isMe
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
                strokeWidth: 2,
              ),
            ),
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = medias.length;
    return GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => AlbumSwipeViewer(
            medias: medias,
            initialIndex: 0,
            senderName: senderName,
            sentAt: sentAt,
          ),
        ),
      ),
      child: SizedBox(
        width: _w + 10,
        height: _h + 10,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Carte du dessous (3ème) — fond neutre légèrement décalé
            if (total >= 3)
              Positioned(
                top: 8,
                left: 6,
                child: Transform.rotate(
                  angle: 0.08,
                  child: Container(
                    width: _w,
                    height: _h,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            // Carte du milieu (2ème) — fond légèrement décalé
            if (total >= 2)
              Positioned(
                top: 4,
                left: 3,
                child: Transform.rotate(
                  angle: 0.04,
                  child: Container(
                    width: _w,
                    height: _h,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            // Carte principale (1ère) — thumbnail réel
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: _w,
                height: _h,
                child: _topThumbnail(context),
              ),
            ),
            // Badge compteur
            if (total > 1)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
