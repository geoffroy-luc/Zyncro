import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/core/app_update/app_update_policy.dart';

void main() {
  group('compareVersions', () {
    test('ordre', () {
      expect(AppUpdatePolicy.compareVersions('1.1.3', '1.1.3'), 0);
      expect(AppUpdatePolicy.compareVersions('1.1.3', '1.2.0'), isNegative);
      expect(AppUpdatePolicy.compareVersions('2.0', '1.9.9'), isPositive);
      expect(AppUpdatePolicy.compareVersions('1.1', '1.1.0'), 0);
      expect(AppUpdatePolicy.compareVersions('1.x.0', '1.0.0'), 0);
    });
  });

  group('evaluate', () {
    UpdateInfo? eval(
      Map<String, dynamic> c,
      String v, [
      AppPlatform p = AppPlatform.android,
    ]) => AppUpdatePolicy.evaluate(config: c, currentVersion: v, platform: p);

    test('à jour → null', () {
      expect(
        eval({'minimum_version': '1.0.0', 'latest_version': '1.1.3'}, '1.1.3'),
        isNull,
      );
      expect(eval({}, '1.1.3'), isNull);
    });
    test('mise à jour optionnelle', () {
      final info = eval({
        'latest_version': '1.2.0',
        'android_url': 'https://play',
      }, '1.1.3')!;
      expect(info.isMandatory, isFalse);
      expect(info.latestVersion, '1.2.0');
      expect(info.storeUrl, 'https://play');
    });
    test('mise à jour obligatoire (minimum_version)', () {
      final info = eval({'minimum_version': '1.2.0'}, '1.1.3')!;
      expect(info.isMandatory, isTrue);
    });
    test('clés spécifiques à la plateforme prioritaires', () {
      final c = {
        'minimum_version': '9.0.0',
        'ios_minimum_version': '1.0.0',
        'ios_latest_version': '1.1.3',
        'ios_url': 'https://apps',
      };
      expect(eval(c, '1.1.3', AppPlatform.ios), isNull);
      expect(eval(c, '1.1.3')!.isMandatory, isTrue);
    });
  });
}
