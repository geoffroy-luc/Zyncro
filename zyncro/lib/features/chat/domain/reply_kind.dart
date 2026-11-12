import 'dart:convert';

/// Nature d'un message cité, déduite de son contenu (seul le contenu est
/// stocké dans `replyToContent`).
enum ReplyKind { text, photo, video, album, audio, poll }

/// BUG C7 corrigé : auparavant toute citation JSON valait « Sondage » et tout
/// texte commençant par http « Photo / Vidéo ».
ReplyKind replyKindOf(String content) {
  if (!content.trimLeft().startsWith('{')) return ReplyKind.text;
  try {
    final data = jsonDecode(content);
    if (data is! Map<String, dynamic>) return ReplyKind.text;
    if (data['question'] is String && data['options'] is List) {
      return ReplyKind.poll;
    }
    if (data['medias'] is List) return ReplyKind.album;
    if (data['url'] is String && data.containsKey('duration')) {
      return ReplyKind.audio;
    }
    final mime = data['mimeType'];
    if (data['url'] is String && mime is String) {
      return mime.startsWith('video/') ? ReplyKind.video : ReplyKind.photo;
    }
  } on FormatException {
    // Texte qui ressemble à du JSON : affiché tel quel.
  }
  return ReplyKind.text;
}
