import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/core/media/file_extension.dart';

void main() {
  test('BUG M1 corrigé : extension du nom de fichier, sinon du type', () {
    expect(uploadExtension('/a/b/photo.JPG', 'image/jpeg'), 'jpg');
    expect(uploadExtension('/data/com.app/cache/abc', 'image/jpeg'), 'jpg');
    expect(uploadExtension('/data/com.app/cache/abc', 'video/mp4'), 'mp4');
    expect(uploadExtension('/x/clip', 'video/quicktime'), 'mov');
    expect(uploadExtension('/x/.hidden', 'image/png'), 'png');
  });
}
