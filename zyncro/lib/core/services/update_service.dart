import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.isMandatory,
    required this.latestVersion,
    required this.storeUrl,
  });

  final bool isMandatory;
  final String latestVersion;
  final String storeUrl;
}

class UpdateService {
  /// Checks Firestore for update requirements.
  /// Returns [UpdateInfo] if an update is available/required, null otherwise.
  static Future<UpdateInfo?> check() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('app_version')
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final packageInfo = await PackageInfo.fromPlatform();
      final current = packageInfo.version;

      final fallbackMinimum = (data['minimum_version'] as String?) ?? '0.0.0';
      final fallbackLatest = (data['latest_version'] as String?) ?? current;
      final androidUrl = (data['android_url'] as String?) ?? '';
      final iosUrl = (data['ios_url'] as String?) ?? '';

      final String minimumVersion;
      final String latestVersion;
      final String storeUrl;

      if (Platform.isIOS) {
        minimumVersion = (data['ios_minimum_version'] as String?) ?? fallbackMinimum;
        latestVersion = (data['ios_latest_version'] as String?) ?? fallbackLatest;
        storeUrl = iosUrl;
      } else {
        minimumVersion = (data['android_minimum_version'] as String?) ?? fallbackMinimum;
        latestVersion = (data['android_latest_version'] as String?) ?? fallbackLatest;
        storeUrl = androidUrl;
      }

      final isMandatory = _compare(current, minimumVersion) < 0;
      final hasUpdate = _compare(current, latestVersion) < 0;

      if (!isMandatory && !hasUpdate) return null;

      return UpdateInfo(
        isMandatory: isMandatory,
        latestVersion: latestVersion,
        storeUrl: storeUrl,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> openStore(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Returns negative if v1 < v2, 0 if equal, positive if v1 > v2.
  static int _compare(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final a = i < parts1.length ? parts1[i] : 0;
      final b = i < parts2.length ? parts2[i] : 0;
      if (a != b) return a - b;
    }
    return 0;
  }
}
