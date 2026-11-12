import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zyncro/core/app_update/app_update_policy.dart';
import 'package:zyncro/core/firebase/firebase_providers.dart';
import 'package:zyncro/core/firebase/firestore_paths.dart';

/// Vérifie `config/app_version` (lisible sans authentification) et ouvre le
/// store. Mécanisme de mise à jour forcée (docs/refactor/PLAN.md, S3).
class AppUpdateService {
  AppUpdateService(this._db);

  final FirebaseFirestore _db;

  /// [UpdateInfo] si une mise à jour est disponible ou requise, sinon `null`
  /// (y compris en cas d'erreur : la vérification ne bloque jamais l'app).
  Future<UpdateInfo?> check() async {
    try {
      final doc = await _db
          .collection(FirestoreCollections.appConfig)
          .doc(FirestoreDocIds.appVersion)
          .get();
      if (!doc.exists) return null;
      final packageInfo = await PackageInfo.fromPlatform();
      return AppUpdatePolicy.evaluate(
        config: doc.data()!,
        currentVersion: packageInfo.version,
        platform: Platform.isIOS ? AppPlatform.ios : AppPlatform.android,
      );
    } on Object {
      return null;
    }
  }

  Future<void> openStore(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>(
  (ref) => AppUpdateService(ref.watch(firestoreProvider)),
);
