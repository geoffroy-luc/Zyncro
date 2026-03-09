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

class SelectedGroupIdNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kGroupIdKey);
  }

  Future<void> select(String? groupId) async {
    final prefs = await SharedPreferences.getInstance();
    if (groupId == null) {
      await prefs.remove(_kGroupIdKey);
    } else {
      await prefs.setString(_kGroupIdKey, groupId);
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
