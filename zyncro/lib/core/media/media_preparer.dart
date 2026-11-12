import 'package:zyncro/core/media/image_compressor.dart';

/// Média prêt à être envoyé dans le chat.
typedef PreparedMedia = ({String filePath, String mimeType});

/// Préparation des photos / vidéos avant envoi : compression JPEG des images
/// (qualité 85, hauteur min 1920), vidéos inchangées.
///
/// Deux comportements historiques conservés à l'identique :
/// - [prepareBatch] (galerie, partage) : le type devient `image/jpeg` même si
///   la compression échoue (le fichier d'origine est alors envoyé) ;
/// - [prepareSingle] (caméra) : le type ne change que si la compression réussit.
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
        if (media.mimeType.startsWith('image/')) {
          final result = await _compressor.compressJpeg(
            media.path,
            '$dir/${filePrefix}_${ts}_$index.jpg',
            quality: quality,
            minHeight: minHeight,
          );
          return (filePath: result ?? media.path, mimeType: 'image/jpeg');
        }
        return (filePath: media.path, mimeType: media.mimeType);
      }),
    );
  }

  Future<PreparedMedia> prepareSingle(String path, String mimeType) async {
    if (!mimeType.startsWith('image/')) {
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
}
