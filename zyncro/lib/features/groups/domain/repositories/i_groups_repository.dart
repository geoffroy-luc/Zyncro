import '../../../../shared/models/group.dart';
import '../../../../shared/models/group_member.dart';

/// Aperçu d'un groupe résolu depuis un code d'invitation, sans le rejoindre.
class InvitePreview {
  final String groupId;
  final String? groupName;
  final String? groupEmoji;
  final String? groupPhotoUrl;

  const InvitePreview({
    required this.groupId,
    this.groupName,
    this.groupEmoji,
    this.groupPhotoUrl,
  });
}

abstract interface class IGroupsRepository {
  Stream<List<Group>> watchUserGroups(String userId);
  Future<Group> createGroup({
    required String name,
    String? description,
    String? emoji,
    required String userId,
    required String displayName,
    String? photoUrl,
    bool showProfilePhoto,
  });
  Future<void> joinGroup(
    String groupId,
    String userId,
    String displayName, {
    String? photoUrl,
    bool showProfilePhoto,
  });
  Future<Group?> joinGroupByCode(
    String code,
    String userId,
    String displayName, {
    String? photoUrl,
    bool showProfilePhoto,
  });
  /// Résout un code d'invitation en aperçu de groupe (nom / emoji) sans y
  /// adhérer. Utilisé par l'écran de confirmation d'un lien d'invitation.
  Future<InvitePreview?> resolveInviteCode(String code);
  Stream<List<GroupMember>> watchMembers(String groupId);
  Future<void> removeMember(String groupId, String userId);
  Future<void> leaveGroup(String groupId, String userId, {String? systemMessage});
  Future<void> transferOwnership(String groupId, String currentOwnerId, String newOwnerId);
  Future<void> deleteGroup(String groupId, String? inviteCode);
  Future<String> generateInviteCode(String groupId);
  Future<void> updateGroupInfo(String groupId, {required String name, String? description});
  Future<void> updateMemberDisplayName(String groupId, String userId, String displayName);
}
