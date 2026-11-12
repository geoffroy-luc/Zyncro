import 'dart:convert';

import 'package:zyncro/features/chat/domain/entities/message.dart';
import 'package:zyncro/features/chat/presentation/widgets/gallery_item.dart';

List<GalleryItem> galleryBuildItems(List<Message> messages) {
  final items = <GalleryItem>[];
  for (int i = 0; i < messages.length; i++) {
    final message = messages[i];
    try {
      final data = jsonDecode(message.content) as Map<String, dynamic>;
      if (data.containsKey('medias')) {
        final medias = (data['medias'] as List).cast<Map<String, dynamic>>();
        for (int j = 0; j < medias.length; j++) {
          items.add(
            GalleryItem(
              message: message,
              url: medias[j]['url'] as String? ?? '',
              mimeType: medias[j]['mimeType'] as String? ?? '',
              albumMedias: medias,
              albumIndex: j,
              messageIndex: i,
            ),
          );
        }
      } else {
        items.add(
          GalleryItem(
            message: message,
            url: data['url'] as String? ?? '',
            mimeType: data['mimeType'] as String? ?? '',
            albumIndex: 0,
            messageIndex: i,
          ),
        );
      }
    } catch (_) {
      // message mal formé, on ignore
    }
  }
  return items;
}
