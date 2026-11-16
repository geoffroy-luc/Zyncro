import 'package:shared_preferences/shared_preferences.dart';

/// Préférences d'affichage du chat propres à l'appareil (pas partagées avec
/// l'espace, contrairement au fond du chat).
class ChatPreferences {
  const ChatPreferences();

  static const _activityVisible = 'chat_activity_visible';

  /// Afficher l'activité de l'espace (notes, événements, dépenses, arrivées)
  /// dans le chat. Vrai par défaut.
  Future<bool> isActivityVisible() async =>
      (await SharedPreferences.getInstance()).getBool(_activityVisible) ?? true;

  Future<void> setActivityVisible(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_activityVisible, value);
}
