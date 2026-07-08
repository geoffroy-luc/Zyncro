import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/tab_settings_repository.dart';
import '../../../../shared/models/tab_settings.dart';
import 'groups_provider.dart';

final tabSettingsRepositoryProvider = Provider<TabSettingsRepository>(
  (_) => TabSettingsRepository(),
);

final tabSettingsProvider = StreamProvider<TabSettings>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return Stream.value(TabSettings.defaults);
  return ref.watch(tabSettingsRepositoryProvider).watchSettings(groupId);
});
