import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zyncro/features/chat/data/services/link_preview_service.dart';

void main() {
  group('parseLinkMeta', () {
    test('balises OpenGraph, dans les deux ordres d’attributs', () {
      const html = '''
<meta property="og:title" content=" Titre OG ">
<meta content="Desc OG" property='og:description'>
<meta property="og:image" content="https://x/img.png">
<meta property="og:site_name" content="Site">
<title>Ignoré</title>''';
      final m = parseLinkMeta(html, 'https://www.example.com/a');
      expect(m.title, 'Titre OG');
      expect(m.description, 'Desc OG');
      expect(m.imageUrl, 'https://x/img.png');
      expect(m.siteName, 'Site');
    });

    test('repli sur <title>, meta description et hôte sans www.', () {
      const html =
          '<TITLE>Page</TITLE><meta name="description" content="Résumé">';
      final m = parseLinkMeta(html, 'https://www.example.com/a');
      expect(m.title, 'Page');
      expect(m.description, 'Résumé');
      expect(m.imageUrl, isNull);
      expect(m.siteName, 'example.com');
    });
  });

  group('LinkPreviewService', () {
    test('User-Agent identique et succès mis en cache', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        expect(
          req.headers['User-Agent'],
          'Mozilla/5.0 (compatible; Zyncro/1.0)',
        );
        return http.Response('<title>T</title>', 200);
      });
      final service = LinkPreviewService(client: client);
      expect((await service.fetch('https://a.fr'))?.title, 'T');
      expect((await service.fetch('https://a.fr'))?.title, 'T');
      expect(calls, 1);
    });

    test('échec (≠ 200 ou exception) → null, et réessayé ensuite', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        if (calls == 2) throw Exception('réseau');
        return http.Response('', 404);
      });
      final service = LinkPreviewService(client: client);
      expect(await service.fetch('https://a.fr'), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(await service.fetch('https://a.fr'), isNull);
      expect(calls, 2);
    });

    test('cache borné', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return http.Response('<title>T</title>', 200);
      });
      final service = LinkPreviewService(client: client, maxEntries: 1);
      await service.fetch('https://a.fr');
      await service.fetch('https://b.fr');
      await service.fetch('https://a.fr');
      expect(calls, 3);
    });
  });
}
