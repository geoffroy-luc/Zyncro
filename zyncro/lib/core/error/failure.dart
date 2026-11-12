/// Erreur métier unifiée de l'app.
///
/// Les repositories traduisent les exceptions techniques (Firebase, réseau,
/// plugins) en [Failure] via `FailureMapper` ; les controllers les exposent
/// dans un `AsyncValue` ; l'UI affiche le message associé (l10n).
sealed class Failure implements Exception {
  const Failure([this.cause]);

  /// Exception d'origine (journalisation uniquement, jamais affichée brute).
  final Object? cause;

  @override
  String toString() => '$runtimeType(${cause ?? ''})';
}

/// Règles de sécurité : action non autorisée.
final class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure([super.cause]);
}

/// Document ou fichier introuvable.
final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.cause]);
}

/// Réseau indisponible ou service temporairement inaccessible.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.cause]);
}

/// Action annulée par l'utilisateur (sélecteur fermé, connexion abandonnée…).
final class CancelledFailure extends Failure {
  const CancelledFailure([super.cause]);
}

/// Donnée invalide (validation métier). [code] identifie la règle violée.
final class ValidationFailure extends Failure {
  const ValidationFailure(this.code, [super.cause]);
  final String code;
}

/// Erreur non classée.
final class UnknownFailure extends Failure {
  const UnknownFailure([super.cause]);
}
