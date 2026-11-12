import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/core/firebase/firebase_providers.dart';
import 'package:zyncro/core/media/device_image_picker_service.dart';
import 'package:zyncro/core/media/file_storage.dart';
import 'package:zyncro/core/media/firebase_file_storage.dart';
import 'package:zyncro/core/media/gallery_saver.dart';
import 'package:zyncro/core/media/image_compressor.dart';
import 'package:zyncro/core/media/image_picker_service.dart';
import 'package:zyncro/core/media/media_preparer.dart';
import 'package:zyncro/core/media/network_bytes_loader.dart';
import 'package:zyncro/core/media/voice_recorder.dart';

final imagePickerServiceProvider = Provider<ImagePickerService>(
  (_) => DeviceImagePickerService(),
);

final fileStorageProvider = Provider<FileStorage>(
  (ref) => FirebaseFileStorage(ref.watch(firebaseStorageProvider)),
);

final mediaPreparerProvider = Provider<MediaPreparer>(
  (_) => const MediaPreparer(FlutterImageCompressor()),
);

final gallerySaverProvider = Provider<GallerySaver>(
  (_) => const DeviceGallerySaver(FlutterImageCompressor()),
);

/// Dossier temporaire de l'app (enregistrements audio, fichiers transitoires).
final temporaryDirectoryProvider = Provider<Future<String> Function()>(
  (_) => const FlutterImageCompressor().temporaryDirectory,
);

/// Fabrique d'enregistreur vocal (une instance par écran, à disposer).
final voiceRecorderFactoryProvider = Provider<VoiceRecorder Function()>(
  (_) => DeviceVoiceRecorder.new,
);

final networkBytesLoaderProvider = Provider<NetworkBytesLoader>(
  (_) => const NetworkBytesLoader(),
);
