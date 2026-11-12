import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zyncro/core/logging/app_logger.dart';

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
    return handleError((Object error, StackTrace stackTrace) {
      AppLogger.warning(label, 'Firestore permission-denied', error);
      // On relance (même objet, même stack) pour que l'erreur atteigne le
      // StreamProvider et l'UI.
      Error.throwWithStackTrace(error, stackTrace);
    }, test: (e) => e is FirebaseException && e.code == 'permission-denied');
  }
}

/// Convertit les documents d'une requête en ignorant — et en journalisant —
/// ceux qui ne peuvent pas être lus.
///
/// Sans cette protection, un seul document malformé (champ manquant, type
/// inattendu, valeur d'enum inconnue écrite par une version plus récente)
/// faisait échouer tout le stream : l'onglet entier devenait vide ou en
/// erreur pour tous les membres du groupe (BUGS_FOUND D1).
List<T> mapDocsSafely<T>(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  T Function(String id, Map<String, dynamic> data) parse, {
  required String label,
}) {
  final result = <T>[];
  for (final doc in docs) {
    try {
      result.add(parse(doc.id, doc.data()));
    } catch (error) {
      // Error (TypeError, ArgumentError de values.byName…) autant qu'Exception :
      // on ne veut perdre que le document fautif, jamais la liste.
      AppLogger.warning(
        label,
        'document ignoré (${doc.reference.path})',
        error,
      );
    }
  }
  return result;
}
