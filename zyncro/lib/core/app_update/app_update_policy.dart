/// Résultat de la vérification de version (dialog obligatoire ou optionnel).
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

/// Plateforme pour laquelle on lit la configuration de version.
enum AppPlatform { android, ios }

/// Décide, à partir de `config/app_version` (carte brute) et de la version
/// installée, s'il faut proposer ou imposer une mise à jour. Logique pure.
abstract final class AppUpdatePolicy {
  static UpdateInfo? evaluate({
    required Map<String, dynamic> config,
    required String currentVersion,
    required AppPlatform platform,
  }) {
    final fallbackMinimum = (config['minimum_version'] as String?) ?? '0.0.0';
    final fallbackLatest =
        (config['latest_version'] as String?) ?? currentVersion;
    final androidUrl = (config['android_url'] as String?) ?? '';
    final iosUrl = (config['ios_url'] as String?) ?? '';

    final String minimumVersion;
    final String latestVersion;
    final String storeUrl;
    if (platform == AppPlatform.ios) {
      minimumVersion =
          (config['ios_minimum_version'] as String?) ?? fallbackMinimum;
      latestVersion =
          (config['ios_latest_version'] as String?) ?? fallbackLatest;
      storeUrl = iosUrl;
    } else {
      minimumVersion =
          (config['android_minimum_version'] as String?) ?? fallbackMinimum;
      latestVersion =
          (config['android_latest_version'] as String?) ?? fallbackLatest;
      storeUrl = androidUrl;
    }

    final isMandatory = compareVersions(currentVersion, minimumVersion) < 0;
    final hasUpdate = compareVersions(currentVersion, latestVersion) < 0;
    if (!isMandatory && !hasUpdate) return null;
    return UpdateInfo(
      isMandatory: isMandatory,
      latestVersion: latestVersion,
      storeUrl: storeUrl,
    );
  }

  /// Négatif si [v1] < [v2], 0 si égales, positif sinon (3 composantes,
  /// composante non numérique = 0).
  static int compareVersions(String v1, String v2) {
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
