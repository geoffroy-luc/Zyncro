/// Utilisateur authentifié, indépendant du fournisseur d'authentification.
///
/// Construit par la couche data à partir du `User` Firebase : la présentation
/// et le domaine ne dépendent jamais de `firebase_auth`.
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;

  /// Photo du fournisseur (Google / Apple), pas la photo personnalisée.
  final String? photoUrl;
  final bool isAnonymous;

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isAnonymous = false,
  });
}
