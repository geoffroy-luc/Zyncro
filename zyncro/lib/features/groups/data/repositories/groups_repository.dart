import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/i_groups_repository.dart';
import '../../../../shared/models/group.dart';
import '../../../../shared/models/group_member.dart';

class GroupsRepository implements IGroupsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Stream<List<Group>> watchUserGroups(String userId) {
    return _db
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => Group.fromMap(doc.id, doc.data())).toList(),
        );
  }

  @override
  Future<Group> createGroup({
    required String name,
    String? description,
    String? emoji,
    required String userId,
    required String displayName,
  }) async {
    final code = Group.generateInviteCode();
    final groupRef = _db.collection('groups').doc();
    final group = Group(
      id: groupRef.id,
      name: name,
      description: description,
      emoji: emoji,
      memberIds: [userId],
      createdBy: userId,
      createdAt: DateTime.now(),
      inviteCode: code,
    );

    final batch = _db.batch();
    batch.set(groupRef, group.toMap());
    batch.set(
      groupRef.collection('members').doc(userId),
      {
        'uid': userId,
        'displayName': displayName,
        'role': 'owner',
        'joinedAt': FieldValue.serverTimestamp(),
      },
    );
    // Code → groupId mapping for join-by-code flow
    batch.set(
      _db.collection('invite_codes').doc(code),
      {'groupId': groupRef.id},
    );
    await batch.commit();

    return group;
  }

  @override
  Future<void> joinGroup(
    String groupId,
    String userId,
    String displayName,
  ) async {
    final groupRef = _db.collection('groups').doc(groupId);
    final batch = _db.batch();
    batch.update(groupRef, {
      'memberIds': FieldValue.arrayUnion([userId]),
    });
    batch.set(
      groupRef.collection('members').doc(userId),
      {
        'uid': userId,
        'displayName': displayName,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  @override
  Future<Group?> joinGroupByCode(
    String code,
    String userId,
    String displayName,
  ) async {
    final codeDoc = await _db
        .collection('invite_codes')
        .doc(code.toUpperCase().trim())
        .get();
    if (!codeDoc.exists) return null;

    final groupId = codeDoc.data()!['groupId'] as String;

    // Join first (idempotent: arrayUnion + member doc overwrite).
    // We intentionally skip reading the group doc before joining because
    // the user is not yet a member and the read rule would deny it.
    await joinGroup(groupId, userId, displayName);

    // Now we're a member — read is allowed.
    final updated = await _db.collection('groups').doc(groupId).get();
    if (!updated.exists) return null;
    return Group.fromMap(updated.id, updated.data()!);
  }

  @override
  Stream<List<GroupMember>> watchMembers(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => GroupMember.fromMap(doc.data())).toList(),
        );
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    final groupRef = _db.collection('groups').doc(groupId);
    final batch = _db.batch();
    batch.update(groupRef, {
      'memberIds': FieldValue.arrayRemove([userId]),
    });
    batch.delete(groupRef.collection('members').doc(userId));
    await batch.commit();
  }

  @override
  Future<void> leaveGroup(String groupId, String userId) =>
      removeMember(groupId, userId);

  @override
  Future<String> generateInviteCode(String groupId) async {
    final code = Group.generateInviteCode();
    final batch = _db.batch();
    batch.update(_db.collection('groups').doc(groupId), {'inviteCode': code});
    batch.set(
      _db.collection('invite_codes').doc(code),
      {'groupId': groupId},
    );
    await batch.commit();
    return code;
  }
}
