import 'package:shared_preferences/shared_preferences.dart';

/// Préférence locale « notifications activées » (écran Profil).
///
/// ⚠️ Locale à l'appareil et non scopée par utilisateur (BUGS_FOUND G13) :
/// comportement historique conservé.
class NotificationPreferences {
  static const _key = 'notifications_enabled';

  Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? true;

  Future<void> setEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_key, value);
}
