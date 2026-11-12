import 'package:zyncro/core/media/media_source.dart';

/// Sélection d'une image (caméra ou galerie), redimensionnée et compressée par
/// le système. Renvoie le chemin du fichier local, ou `null` si annulé.
abstract interface class ImagePickerService {
  Future<String?> pickImage({
    required MediaSource source,
    int? imageQuality,
    double? maxWidth,
    double? maxHeight,
  });
}
