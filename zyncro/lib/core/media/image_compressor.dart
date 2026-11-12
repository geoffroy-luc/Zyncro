import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Compression d'images et dossier temporaire (abstraits pour les tests).
abstract interface class ImageCompressor {
  /// Compresse [sourcePath] en JPEG vers [targetPath]. `null` si échec.
  Future<String?> compressJpeg(
    String sourcePath,
    String targetPath, {
    required int quality,
    required int minHeight,
  });

  /// Dossier temporaire de l'app.
  Future<String> temporaryDirectory();
}

class FlutterImageCompressor implements ImageCompressor {
  const FlutterImageCompressor();

  @override
  Future<String?> compressJpeg(
    String sourcePath,
    String targetPath, {
    required int quality,
    required int minHeight,
  }) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      targetPath,
      quality: quality,
      minHeight: minHeight,
    );
    return result?.path;
  }

  @override
  Future<String> temporaryDirectory() async =>
      (await getTemporaryDirectory()).path;
}
