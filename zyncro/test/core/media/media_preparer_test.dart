import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/core/media/image_compressor.dart';
import 'package:zyncro/core/media/media_preparer.dart';

class _FakeCompressor implements ImageCompressor {
  _FakeCompressor({this.fails = false});

  final bool fails;
  final calls = <(String, String, int, int)>[];

  @override
  Future<String?> compressJpeg(
    String sourcePath,
    String targetPath, {
    required int quality,
    required int minHeight,
  }) async {
    calls.add((sourcePath, targetPath, quality, minHeight));
    return fails ? null : targetPath;
  }

  @override
  Future<String> temporaryDirectory() async => '/tmp/z';
}

void main() {
  final clock = DateTime.fromMillisecondsSinceEpoch(1000);

  group('MediaPreparer.prepareBatch', () {
    test('compresse les images en JPEG 85 / 1920, laisse les vidéos', () async {
      final fake = _FakeCompressor();
      final out = await MediaPreparer(fake, clock: () => clock).prepareBatch([
        (path: '/a.png', mimeType: 'image/png'),
        (path: '/b.mp4', mimeType: 'video/mp4'),
      ], filePrefix: 'share');

      expect(out, [
        (filePath: '/tmp/z/share_1000_0.jpg', mimeType: 'image/jpeg'),
        (filePath: '/b.mp4', mimeType: 'video/mp4'),
      ]);
      expect(fake.calls.single, (
        '/a.png',
        '/tmp/z/share_1000_0.jpg',
        85,
        1920,
      ));
    });

    test('échec de compression : fichier d’origine, mime forcé JPEG', () async {
      final out =
          await MediaPreparer(
            _FakeCompressor(fails: true),
            clock: () => clock,
          ).prepareBatch([
            (path: '/a.png', mimeType: 'image/png'),
          ], filePrefix: 'compressed');

      expect(out.single, (filePath: '/a.png', mimeType: 'image/jpeg'));
    });
  });

  group('MediaPreparer.prepareSingle', () {
    test('image compressée → JPEG', () async {
      final out = await MediaPreparer(
        _FakeCompressor(),
        clock: () => clock,
      ).prepareSingle('/a.heic', 'image/heic');
      expect(out, (
        filePath: '/tmp/z/compressed_1000.jpg',
        mimeType: 'image/jpeg',
      ));
    });

    test('échec de compression : fichier et mime inchangés', () async {
      final out = await MediaPreparer(
        _FakeCompressor(fails: true),
        clock: () => clock,
      ).prepareSingle('/a.heic', 'image/heic');
      expect(out, (filePath: '/a.heic', mimeType: 'image/heic'));
    });

    test('vidéo : jamais compressée', () async {
      final fake = _FakeCompressor();
      final out = await MediaPreparer(
        fake,
        clock: () => clock,
      ).prepareSingle('/v.mp4', 'video/mp4');
      expect(out, (filePath: '/v.mp4', mimeType: 'video/mp4'));
      expect(fake.calls, isEmpty);
    });
  });
}
