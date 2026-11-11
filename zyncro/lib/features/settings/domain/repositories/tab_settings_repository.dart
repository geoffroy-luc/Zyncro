import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';

abstract interface class TabSettingsRepository {
  Stream<TabSettings> watchSettings(String groupId);

  /// Écrit uniquement les champs qui diffèrent entre [from] (état à partir
  /// duquel l'utilisateur a fait sa modification) et [to].
  Future<void> updateSettings(
    String groupId, {
    required TabSettings from,
    required TabSettings to,
  });
}
