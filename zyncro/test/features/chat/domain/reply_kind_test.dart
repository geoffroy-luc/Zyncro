import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/chat/domain/reply_kind.dart';

void main() {
  test('BUG C7 corrigé : nature de la citation selon le contenu', () {
    expect(replyKindOf('Salut'), ReplyKind.text);
    expect(replyKindOf('https://exemple.fr'), ReplyKind.text);
    expect(replyKindOf('{pas du json'), ReplyKind.text);
    expect(
      replyKindOf(jsonEncode({'url': 'u', 'mimeType': 'image/jpeg'})),
      ReplyKind.photo,
    );
    expect(
      replyKindOf(jsonEncode({'url': 'u', 'mimeType': 'video/mp4'})),
      ReplyKind.video,
    );
    expect(
      replyKindOf(
        jsonEncode({
          'medias': [
            {'url': 'u', 'mimeType': 'image/jpeg'},
          ],
        }),
      ),
      ReplyKind.album,
    );
    expect(
      replyKindOf(jsonEncode({'url': 'u', 'duration': 3})),
      ReplyKind.audio,
    );
    expect(
      replyKindOf(
        jsonEncode({
          'question': 'Q ?',
          'options': ['a', 'b'],
          'multipleChoice': false,
        }),
      ),
      ReplyKind.poll,
    );
  });
}
