import 'package:zyncro/core/media/image_compressor.dart';

/// Média prêt à être envoyé dans le chat.
typedef PreparedMedia = ({String filePath, String mimeType});

/// Préparation des photos / vidéos avant envoi : compression JPEG des images
/// (qualité 85, hauteur min 1920), vidéos inchangées.
///
/// Le type ne devient `image/jpeg` que si la compression réussit (sinon le
/// fichier d'origine part avec son type) ; les GIF ne sont pas compressés
/// (BUG M2 corrigé).
class MediaPreparer {
  const MediaPreparer(this._compressor, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const quality = 85;
  static const minHeight = 1920;

  final ImageCompressor _compressor;
  final DateTime Function() _clock;

  Future<List<PreparedMedia>> prepareBatch(
    List<({String path, String mimeType})> medias, {
    required String filePrefix,
  }) async {
    final dir = await _compressor.temporaryDirectory();
    final ts = _clock().millisecondsSinceEpoch;
    return Future.wait(
      medias.asMap().entries.map((e) async {
        final index = e.key;
        final media = e.value;
        if (_compressible(media.mimeType)) {
          final result = await _compressor.compressJpeg(
            media.path,
            '$dir/${filePrefix}_${ts}_$index.jpg',
            quality: quality,
            minHeight: minHeight,
          );
          // BUG M2 corrigé : sans compression, le type d'origine est gardé
          // (une image PNG / HEIC non compressée partait en image/jpeg).
          if (result != null) return (filePath: result, mimeType: 'image/jpeg');
        }
        return (filePath: media.path, mimeType: media.mimeType);
      }),
    );
  }

  Future<PreparedMedia> prepareSingle(String path, String mimeType) async {
    if (!_compressible(mimeType)) {
      return (filePath: path, mimeType: mimeType);
    }
    final dir = await _compressor.temporaryDirectory();
    final result = await _compressor.compressJpeg(
      path,
      '$dir/compressed_${_clock().millisecondsSinceEpoch}.jpg',
      quality: quality,
      minHeight: minHeight,
    );
    if (result != null) return (filePath: result, mimeType: 'image/jpeg');
    return (filePath: path, mimeType: mimeType);
  }

  /// Images compressées en JPEG ; BUG M2 corrigé : les GIF restent tels
  /// quels (la conversion perdait l'animation).
  static bool _compressible(String mimeType) =>
      mimeType.startsWith('image/') && mimeType != 'image/gif';
}
