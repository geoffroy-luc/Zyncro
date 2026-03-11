import '../../../../shared/models/group.dart';
import '../../../../shared/models/group_member.dart';

abstract interface class IGroupsRepository {
  Stream<List<Group>> watchUserGroups(String userId);
  Future<Group> createGroup({
    required String name,
    String? description,
    String? emoji,
    required String userId,
    required String displayName,
  });
  Future<void> joinGroup(String groupId, String userId, String displayName);
  Future<Group?> joinGroupByCode(String code, String userId, String displayName);
  Stream<List<GroupMember>> watchMembers(String groupId);
  Future<void> removeMember(String groupId, String userId);
  Future<void> leaveGroup(String groupId, String userId, {String? systemMessage});
  Future<void> transferOwnership(String groupId, String currentOwnerId, String newOwnerId);
  Future<void> deleteGroup(String groupId, String? inviteCode);
  Future<String> generateInviteCode(String groupId);
}
