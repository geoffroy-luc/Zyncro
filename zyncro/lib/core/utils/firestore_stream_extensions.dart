import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

extension FirestoreStreamErrors<T> on Stream<T> {
  /// Gère les erreurs `permission-denied` de Firestore sans jamais figer le
  /// stream.
  ///
  /// Auparavant ces erreurs étaient avalées silencieusement
  /// (`handleError((_) {})`) : le stream se terminait sans rien émettre, ce qui
  /// laissait les `StreamProvider` bloqués en état `loading` → spinner infini.
  ///
  /// Ici on journalise l'erreur (visible dans la console / logcat, y compris en
  /// build release) puis on la laisse **remonter** pour que l'UI affiche un vrai
  /// état d'erreur au lieu de tourner indéfiniment.
  ///
  /// [label] identifie la source dans les logs (ex: `'watchUserGroups'`).
  Stream<T> surfacePermissionDenied(String label) {
    return handleError(
      (Object error, StackTrace _) {
        debugPrint('[$label] Firestore permission-denied: $error');
        // On relance pour que l'erreur atteigne le StreamProvider et l'UI.
        throw error;
      },
      test: (e) => e is FirebaseException && e.code == 'permission-denied',
    );
  }
}
