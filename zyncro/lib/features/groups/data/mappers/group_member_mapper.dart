import 'package:zyncro/features/groups/domain/entities/group_member.dart';
import 'package:zyncro/shared/data/mappers/firestore_codec.dart';

/// Champs Firestore d'un membre (`groups/{gid}/members/{uid}`).
abstract final class GroupMemberFields {
  static const uid = 'uid';
  static const displayName = 'displayName';
  static const role = 'role';
  static const joinedAt = 'joinedAt';
  static const photoUrl = 'photoUrl';
  static const showProfilePhoto = 'showProfilePhoto';
  static const lastReadMessageId = 'lastReadMessageId';
  static const lastReadAt = 'lastReadAt';
}

/// Valeurs de `role` stockées (contrat avec les rules et la v1.1.3).
abstract final class GroupRoles {
  static const owner = 'owner';
  static const member = 'member';
}

abstract final class GroupMemberMapper {
  static GroupMember fromFirestore(Map<String, dynamic> map) {
    return GroupMember(
      uid: map[GroupMemberFields.uid] as String? ?? '',
      displayName: map[GroupMemberFields.displayName] as String? ?? 'Membre',
      role: map[GroupMemberFields.role] as String? ?? GroupRoles.member,
      joinedAt: FirestoreCodec.toDateOrNull(map[GroupMemberFields.joinedAt]),
      photoUrl: map[GroupMemberFields.photoUrl] as String?,
      showProfilePhoto:
          map[GroupMemberFields.showProfilePhoto] as bool? ?? true,
      lastReadMessageId: map[GroupMemberFields.lastReadMessageId] as String?,
      lastReadAt: FirestoreCodec.toDateOrNull(
        map[GroupMemberFields.lastReadAt],
      ),
    );
  }
}
