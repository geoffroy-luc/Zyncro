import 'package:zyncro/features/chat/domain/entities/message.dart';

// Représente un média individuel (image ou vidéo), qu'il vienne d'un message
// unique ou d'un album multi-médias.
class GalleryItem {
  final Message message;
  final String url;
  final String mimeType;
  final List<Map<String, dynamic>>? albumMedias; // null si média seul
  final int albumIndex;
  final int messageIndex;

  const GalleryItem({
    required this.message,
    required this.url,
    required this.mimeType,
    this.albumMedias,
    required this.albumIndex,
    required this.messageIndex,
  });

  bool get isVideo => mimeType.startsWith('video/');
  bool get isAlbum => albumMedias != null;
}
