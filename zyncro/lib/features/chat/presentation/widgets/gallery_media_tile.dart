import 'package:flutter/material.dart';
import 'package:zyncro/features/chat/presentation/screens/album_swipe_viewer.dart';
import 'package:zyncro/features/chat/presentation/widgets/gallery_image_thumb.dart';
import 'package:zyncro/features/chat/presentation/widgets/gallery_item.dart';
import 'package:zyncro/features/chat/presentation/widgets/gallery_video_thumb.dart';

class GalleryMediaTile extends StatelessWidget {
  final GalleryItem item;
  final List<Map<String, dynamic>> viewerItems;
  final int viewerIndex;

  const GalleryMediaTile({
    super.key,
    required this.item,
    required this.viewerItems,
    required this.viewerIndex,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AlbumSwipeViewer(medias: viewerItems, initialIndex: viewerIndex),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          item.isVideo
              ? GalleryVideoThumb(url: item.url)
              : GalleryImageThumb(url: item.url),
          // Badge album (numéro dans l'album) en haut à droite
          if (item.isAlbum)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.white,
                      size: 10,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${item.albumIndex + 1}/${item.albumMedias!.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
