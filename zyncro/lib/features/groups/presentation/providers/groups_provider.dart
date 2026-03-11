import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/groups_repository.dart';
import '../../domain/repositories/i_groups_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/models/group.dart';

final groupsRepositoryProvider = Provider<IGroupsRepository>(
  (_) => GroupsRepository(),
);

final userGroupsProvider = StreamProvider<List<Group>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value([]);
  return ref.watch(groupsRepositoryProvider).watchUserGroups(user.uid);
});

const _kGroupIdKey = 'selected_group_id';
const _kGroupUserKey = 'selected_group_uid';

class SelectedGroupIdNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final user = ref.watch(authStateProvider).asData?.value;
    // Pas connecté → aucun groupe
    if (user == null) return null;

    // Surveille la liste des groupes pour détecter la suppression du groupe sélectionné
    final groups = ref.watch(userGroupsProvider).asData?.value;

    final prefs = await SharedPreferences.getInstance();
    final storedUid = prefs.getString(_kGroupUserKey);

    // Le groupId stocké appartient à un autre compte → on le rejette
    if (storedUid != user.uid) {
      await prefs.remove(_kGroupIdKey);
      await prefs.remove(_kGroupUserKey);
      return null;
    }

    final storedId = prefs.getString(_kGroupIdKey);

    // Si la liste est chargée et que le groupe n'existe plus → on le désélectionne
    if (storedId != null && groups != null && !groups.any((g) => g.id == storedId)) {
      await prefs.remove(_kGroupIdKey);
      await prefs.remove(_kGroupUserKey);
      return null;
    }

    return storedId;
  }

  Future<void> select(String? groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (groupId == null || uid == null) {
      await prefs.remove(_kGroupIdKey);
      await prefs.remove(_kGroupUserKey);
    } else {
      await prefs.setString(_kGroupIdKey, groupId);
      await prefs.setString(_kGroupUserKey, uid);
    }
    state = AsyncData(groupId);
  }
}

final selectedGroupIdProvider =
    AsyncNotifierProvider<SelectedGroupIdNotifier, String?>(
      SelectedGroupIdNotifier.new,
    );

final selectedGroupProvider = Provider<Group?>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return null;
  final groups = ref.watch(userGroupsProvider).asData?.value;
  if (groups == null) return null;
  try {
    return groups.firstWhere((g) => g.id == groupId);
  } catch (_) {
    return null;
  }
});
