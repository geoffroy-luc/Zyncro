import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Téléchargement brut d'une ressource (ex. photo de groupe pour l'icône des
/// raccourcis de partage). `null` si code ≠ 200 ou erreur.
class NetworkBytesLoader {
  const NetworkBytesLoader();

  Future<Uint8List?> load(String url, {required Duration timeout}) async {
    final resp = await http.get(Uri.parse(url)).timeout(timeout);
    return resp.statusCode == 200 ? resp.bodyBytes : null;
  }
}
