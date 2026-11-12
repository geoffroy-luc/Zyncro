/// Enregistrement du token FCM de l'utilisateur (`users/{uid}.fcmToken`).
abstract interface class PushTokenRepository {
  /// Enregistre le token avec un horodatage serveur (initialisation, refresh).
  Future<void> saveToken(String uid, String token);

  /// Enregistre le token seul (réactivation depuis le profil).
  Future<void> saveTokenOnly(String uid, String token);

  /// Efface le token (déconnexion, désactivation).
  Future<void> clearToken(String uid);
}
