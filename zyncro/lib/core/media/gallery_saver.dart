import 'dart:io';

import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:zyncro/core/media/image_compressor.dart';

/// Téléchargement d'un média distant puis enregistrement dans la galerie du
/// téléphone. Point d'extension « télécharger toutes les photos ».
abstract interface class GallerySaver {
  /// Lève une exception en cas d'échec (HTTP, écriture, galerie).
  Future<void> saveImageFromUrl(String url);
  Future<void> saveVideoFromUrl(String url);
}

class DeviceGallerySaver implements GallerySaver {
  const DeviceGallerySaver(this._files, {http.Client? client})
    : _client = client;

  final ImageCompressor _files;
  final http.Client? _client;

  Future<File> _download(String url, String extension) async {
    final response = _client == null
        ? await http.get(Uri.parse(url))
        : await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final dir = await _files.temporaryDirectory();
    final file = File(
      '$dir/zyncro_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await file.writeAsBytes(response.bodyBytes);
    file.setLastModifiedSync(DateTime.now());
    return file;
  }

  @override
  Future<void> saveImageFromUrl(String url) async =>
      Gal.putImage((await _download(url, 'jpg')).path);

  @override
  Future<void> saveVideoFromUrl(String url) async =>
      Gal.putVideo((await _download(url, 'mp4')).path);
}
