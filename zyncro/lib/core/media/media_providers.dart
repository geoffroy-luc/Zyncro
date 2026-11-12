import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/core/firebase/firebase_providers.dart';
import 'package:zyncro/core/media/device_image_picker_service.dart';
import 'package:zyncro/core/media/file_storage.dart';
import 'package:zyncro/core/media/firebase_file_storage.dart';
import 'package:zyncro/core/media/image_picker_service.dart';

final imagePickerServiceProvider = Provider<ImagePickerService>(
  (_) => DeviceImagePickerService(),
);

final fileStorageProvider = Provider<FileStorage>(
  (ref) => FirebaseFileStorage(ref.watch(firebaseStorageProvider)),
);
