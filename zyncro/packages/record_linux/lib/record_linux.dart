import 'dart:typed_data';

import 'package:record_platform_interface/record_platform_interface.dart';

class RecordLinux extends RecordPlatform {
  RecordLinux();

  static void registerWith() {
    RecordPlatform.instance = RecordLinux();
  }

  Never _unsupported() =>
      throw UnsupportedError('record_linux: not supported on this platform');

  @override
  Future<void> create(String recorderId) async => _unsupported();

  @override
  Future<void> start(
    String recorderId,
    RecordConfig config, {
    required String path,
  }) async =>
      _unsupported();

  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async =>
      _unsupported();

  @override
  Future<String?> stop(String recorderId) async => _unsupported();

  @override
  Future<void> cancel(String recorderId) async => _unsupported();

  @override
  Future<void> pause(String recorderId) async => _unsupported();

  @override
  Future<void> resume(String recorderId) async => _unsupported();

  @override
  Future<bool> isRecording(String recorderId) async => false;

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  Future<bool> hasPermission(
    String recorderId, {
    bool request = true,
  }) async =>
      false;

  @override
  Future<void> dispose(String recorderId) async {}

  @override
  Future<Amplitude> getAmplitude(String recorderId) async =>
      Amplitude(current: -160.0, max: -160.0);

  @override
  Future<bool> isEncoderSupported(
    String recorderId,
    AudioEncoder encoder,
  ) async =>
      false;

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async => [];

  @override
  RecordIos? getIos(String recorderId) => null;

  @override
  Stream<RecordState> onStateChanged(String recorderId) => Stream.empty();
}
