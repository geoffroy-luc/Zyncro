/// Configuration des liens d'invitation.
///
/// Un lien d'invitation encapsule le code d'invitation d'un groupe :
///   https://zyncro-f5fdd.web.app/i/AB4K9P
///
/// - Sur mobile avec l'app installée : le lien ouvre Zyncro directement
///   (App Links Android / Universal Links iOS) sur l'écran de confirmation.
/// - Sinon : une page web propose de télécharger l'app.
class InviteLink {
  InviteLink._();

  /// Domaine hébergeant la page de repli + les fichiers de vérification
  /// (assetlinks.json / apple-app-site-association).
  ///
  /// Doit rester synchronisé avec :
  ///  - `android/app/src/main/AndroidManifest.xml` (intent-filter App Links)
  ///  - `ios/Runner/Runner.entitlements` (associated domains)
  ///  - `firebase.json` (hosting)
  static const String host = 'zyncro-f5fdd.web.app';

  /// Segment de chemin utilisé pour les invitations (`/i/<code>`).
  static const String pathPrefix = 'i';

  /// Construit le lien d'invitation partageable pour un [code] donné.
  static String forCode(String code) =>
      'https://$host/$pathPrefix/${code.toUpperCase().trim()}';

  /// Extrait le code d'invitation d'une URI reçue (App Link, Universal Link
  /// ou schéma personnalisé), ou `null` si l'URI ne correspond pas.
  ///
  /// Formats acceptés :
  ///   `https://<host>/i/CODE`
  ///   `zyncro://i/CODE`   (repli schéma personnalisé)
  static String? codeFromUri(Uri uri) {
    final segments = uri.pathSegments;
    // Schéma personnalisé : zyncro://i/CODE → host == 'i', pas de pathPrefix.
    if (uri.scheme == 'zyncro' && uri.host == pathPrefix) {
      return segments.isNotEmpty ? _clean(segments.first) : null;
    }
    // App Link / Universal Link : https://host/i/CODE
    if (segments.length >= 2 && segments[0] == pathPrefix) {
      return _clean(segments[1]);
    }
    return null;
  }

  static String? _clean(String raw) {
    final code = raw.toUpperCase().trim();
    return code.isEmpty ? null : code;
  }
}
