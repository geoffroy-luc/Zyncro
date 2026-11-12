import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:zyncro/features/chat/domain/entities/link_meta.dart';

/// Aperçu d'un lien (balises OpenGraph de la page), avec cache mémoire : un
/// lien réussi n'est téléchargé qu'une fois par session (auparavant à chaque
/// montage de la bulle). Les échecs ne sont pas mémorisés : un nouveau montage
/// réessaie, comme avant.
class LinkPreviewService {
  LinkPreviewService({http.Client? client, this.maxEntries = 200})
    : _client = client;

  final http.Client? _client;
  final int maxEntries;

  /// Succès uniquement, du plus ancien au plus récent (LRU).
  final Map<String, LinkMeta> _cache = {};
  final Map<String, Future<LinkMeta?>> _inFlight = {};

  /// `null` si la page est inaccessible (code ≠ 200, délai de 6 s, erreur).
  Future<LinkMeta?> fetch(String url) async {
    final hit = _cache.remove(url);
    if (hit != null) return _cache[url] = hit;
    final meta = await (_inFlight[url] ??= _download(url));
    _inFlight.remove(url)?.ignore();
    if (meta != null) {
      _cache[url] = meta;
      if (_cache.length > maxEntries) _cache.remove(_cache.keys.first);
    }
    return meta;
  }

  Future<LinkMeta?> _download(String url) async {
    try {
      final uri = Uri.parse(url);
      const headers = {'User-Agent': 'Mozilla/5.0 (compatible; Zyncro/1.0)'};
      final response =
          await (_client == null
                  ? http.get(uri, headers: headers)
                  : _client.get(uri, headers: headers))
              .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      return parseLinkMeta(response.body, url);
    } on Object {
      return null;
    }
  }
}

/// Extrait titre, description, image et site d'une page HTML (pur, testé).
LinkMeta parseLinkMeta(String html, String url) => LinkMeta(
  title: _ogTag(html, 'og:title') ?? _htmlTitle(html),
  description: _ogTag(html, 'og:description') ?? _metaTag(html, 'description'),
  imageUrl: _ogTag(html, 'og:image'),
  siteName:
      _ogTag(html, 'og:site_name') ??
      Uri.parse(url).host.replaceFirst('www.', ''),
);

String? _ogTag(String html, String property) {
  final r1 = RegExp(
    'property=["\']${RegExp.escape(property)}["\'][^>]*content=["\']([^"\']*)["\']',
    caseSensitive: false,
  );
  final r2 = RegExp(
    'content=["\']([^"\']*)["\'][^>]*property=["\']${RegExp.escape(property)}["\']',
    caseSensitive: false,
  );
  return (r1.firstMatch(html) ?? r2.firstMatch(html))?.group(1)?.trim();
}

String? _metaTag(String html, String name) {
  final r1 = RegExp(
    'name=["\']${RegExp.escape(name)}["\'][^>]*content=["\']([^"\']*)["\']',
    caseSensitive: false,
  );
  final r2 = RegExp(
    'content=["\']([^"\']*)["\'][^>]*name=["\']${RegExp.escape(name)}["\']',
    caseSensitive: false,
  );
  return (r1.firstMatch(html) ?? r2.firstMatch(html))?.group(1)?.trim();
}

String? _htmlTitle(String html) => RegExp(
  r'<title[^>]*>([^<]+)</title>',
  caseSensitive: false,
).firstMatch(html)?.group(1)?.trim();
