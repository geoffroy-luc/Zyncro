import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/core/firebase/firebase_providers.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/settings/data/repositories/firestore_tab_settings_repository.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/domain/repositories/tab_settings_repository.dart';

final tabSettingsRepositoryProvider = Provider<TabSettingsRepository>(
  (ref) => FirestoreTabSettingsRepository(ref.watch(firestoreProvider)),
);

final tabSettingsProvider = StreamProvider<TabSettings>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return Stream.value(TabSettings.defaults);
  return ref.watch(tabSettingsRepositoryProvider).watchSettings(groupId);
});
