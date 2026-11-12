import 'package:record/record.dart';

/// Enregistrement de messages vocaux (une instance par écran).
abstract interface class VoiceRecorder {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<void> cancel();

  /// Chemin du fichier enregistré, ou `null`.
  Future<String?> stop();
  Future<void> dispose();
}

class DeviceVoiceRecorder implements VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) =>
      _recorder.start(const RecordConfig(), path: path);

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> dispose() => _recorder.dispose();
}
