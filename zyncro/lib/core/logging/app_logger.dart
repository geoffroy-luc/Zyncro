import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Journalisation de l'app.
///
/// - `debug` / `info` : seulement en debug.
/// - `warning` / `error` : toujours (logcat / console), y compris en release,
///   comme les `debugPrint` qu'ils remplacent.
///
/// Ne jamais y passer de token, mot de passe ou donnée personnelle.
/// Point d'extension : un sink de crash reporting pourra être branché ici.
abstract final class AppLogger {
  static void debug(String tag, String message) {
    if (kDebugMode) developer.log(message, name: tag, level: 500);
  }

  static void info(String tag, String message) {
    if (kDebugMode) developer.log(message, name: tag, level: 800);
  }

  static void warning(String tag, String message, [Object? error]) {
    debugPrint('[$tag] $message${error == null ? '' : ' : $error'}');
  }

  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    debugPrint('[$tag] $message${error == null ? '' : ' : $error'}');
    if (kDebugMode && stackTrace != null) {
      developer.log(
        message,
        name: tag,
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }
}
