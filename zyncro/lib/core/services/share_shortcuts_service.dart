import 'dart:io';

import 'package:flutter/services.dart';

/// Un groupe à publier comme raccourci de partage direct (Direct Share).
class GroupShortcut {
  final String id;
  final String label;

  /// PNG de l'avatar du groupe (optionnel). Si null, le natif dessine une
  /// pastille colorée avec l'initiale.
  final Uint8List? iconPng;

  const GroupShortcut({required this.id, required this.label, this.iconPng});
}

/// Pont vers le code natif Android (MethodChannel) qui gère les raccourcis de
/// partage direct et la lecture du groupe choisi depuis la feuille de partage.
class ShareShortcutsService {
  static const _channel = MethodChannel('com.zyncro.app/share_shortcuts');

  /// Remplace l'ensemble des raccourcis dynamiques par les groupes fournis
  /// (dans l'ordre = ordre de rang souhaité, les plus actifs en premier).
  static Future<void> pushGroups(List<GroupShortcut> groups) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('pushGroupShortcuts', {
        'groups': groups
            .map((g) => {'id': g.id, 'label': g.label, 'iconPng': g.iconPng})
            .toList(),
      });
    } on PlatformException {
      // API indisponible / quota — non bloquant.
    } on MissingPluginException {
      // Plateforme sans le canal natif — ignoré.
    }
  }

  /// Retourne (et efface) l'ID du groupe choisi lorsque l'utilisateur a lancé
  /// Zyncro via un raccourci de partage direct. Null si partage « générique ».
  static Future<String?> consumeShareTargetGroupId() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('consumeShareTargetGroupId');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Supprime tous les raccourcis dynamiques (ex. déconnexion).
  static Future<void> clearAll() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('clearAllShortcuts');
    } on PlatformException {
      // ignoré
    } on MissingPluginException {
      // ignoré
    }
  }
}
