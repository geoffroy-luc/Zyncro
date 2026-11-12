import 'package:image_picker/image_picker.dart';
import 'package:zyncro/core/media/image_picker_service.dart';
import 'package:zyncro/core/media/media_source.dart';

class DeviceImagePickerService implements ImagePickerService {
  DeviceImagePickerService([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickImage({
    required MediaSource source,
    int? imageQuality,
    double? maxWidth,
    double? maxHeight,
  }) async {
    final file = await _picker.pickImage(
      source: switch (source) {
        MediaSource.camera => ImageSource.camera,
        MediaSource.gallery => ImageSource.gallery,
      },
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    return file?.path;
  }
}
