import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/core/media/gallery_saver.dart';
import 'package:zyncro/core/media/media_providers.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/l10n/generated/app_localizations.dart';

// ── Utilitaire de téléchargement partagé ─────────────────────────────────────

/// Enregistrement d'un média dans la galerie, avec retour à l'utilisateur.
/// La partie technique est dans core/media (GallerySaver).
class MediaDownloader {
  static Future<void> downloadImage(BuildContext context, String url) => _save(
    context,
    url,
    (saver) => saver.saveImageFromUrl(url),
    (l10n) => l10n.chatImageEnregistreeDansLaGalerie,
  );

  static Future<void> downloadVideo(BuildContext context, String url) => _save(
    context,
    url,
    (saver) => saver.saveVideoFromUrl(url),
    (l10n) => l10n.chatVideoEnregistreeDansLaGalerie,
  );

  static Future<void> _save(
    BuildContext context,
    String url,
    Future<void> Function(GallerySaver saver) save,
    String Function(AppLocalizations l10n) successMessage,
  ) async {
    // BUG M11 corrigé : message clair au lieu de l'exception brute.
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatMediaIndisponible)),
      );
      return;
    }
    final saver = ProviderScope.containerOf(context).read(gallerySaverProvider);
    try {
      await save(saver);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage(context.l10n))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatErreurTelechargement(e))),
        );
      }
    }
  }
}
