import 'package:zyncro/features/groups/domain/entities/group.dart';
import 'package:zyncro/shared/data/mappers/firestore_codec.dart';

/// Champs Firestore d'un groupe (`groups/{gid}`).
abstract final class GroupFields {
  static const name = 'name';
  static const description = 'description';
  static const emoji = 'emoji';
  static const photoUrl = 'photoUrl';
  static const memberIds = 'memberIds';
  static const createdBy = 'createdBy';
  static const createdAt = 'createdAt';
  static const inviteCode = 'inviteCode';
}

abstract final class GroupMapper {
  static Group fromFirestore(String id, Map<String, dynamic> map) {
    return Group(
      id: id,
      name: map[GroupFields.name] as String,
      description: map[GroupFields.description] as String?,
      emoji: map[GroupFields.emoji] as String?,
      photoUrl: map[GroupFields.photoUrl] as String?,
      memberIds: FirestoreCodec.stringList(map[GroupFields.memberIds]),
      createdBy: map[GroupFields.createdBy] as String,
      createdAt: FirestoreCodec.toDate(map[GroupFields.createdAt]),
      inviteCode: map[GroupFields.inviteCode] as String?,
    );
  }

  static Map<String, dynamic> toFirestore(Group group) => {
    GroupFields.name: group.name,
    GroupFields.description: group.description,
    GroupFields.emoji: group.emoji,
    GroupFields.photoUrl: group.photoUrl,
    GroupFields.memberIds: group.memberIds,
    GroupFields.createdBy: group.createdBy,
    GroupFields.createdAt: FirestoreCodec.fromDate(group.createdAt),
    if (group.inviteCode != null) GroupFields.inviteCode: group.inviteCode,
  };
}
