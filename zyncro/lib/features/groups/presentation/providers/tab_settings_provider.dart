import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/core/firebase/firebase_providers.dart';
import 'package:zyncro/features/groups/data/repositories/tab_settings_repository.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/shared/models/tab_settings.dart';

final tabSettingsRepositoryProvider = Provider<TabSettingsRepository>(
  (ref) => TabSettingsRepository(ref.watch(firestoreProvider)),
);

final tabSettingsProvider = StreamProvider<TabSettings>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return Stream.value(TabSettings.defaults);
  return ref.watch(tabSettingsRepositoryProvider).watchSettings(groupId);
});
