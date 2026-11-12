import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:zyncro/core/firebase/firestore_paths.dart';
import 'package:zyncro/core/utils/firestore_stream_extensions.dart';
import 'package:zyncro/features/groups/data/mappers/group_mapper.dart';
import 'package:zyncro/features/groups/data/mappers/group_member_mapper.dart';
import 'package:zyncro/features/groups/domain/entities/group.dart';
import 'package:zyncro/features/groups/domain/entities/group_member.dart';
import 'package:zyncro/features/groups/domain/repositories/groups_repository.dart';
import 'package:zyncro/features/groups/domain/services/invite_code_generator.dart';

class FirestoreGroupsRepository implements GroupsRepository {
  FirestoreGroupsRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  @override
  Stream<List<Group>> watchUserGroups(String userId) {
    return _db
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map(
          (snap) => mapDocsSafely(
            snap.docs,
            GroupMapper.fromFirestore,
            label: 'watchUserGroups',
          ),
        )
        .surfacePermissionDenied('watchUserGroups');
  }

  @override
  Future<Group> createGroup({
    required String name,
    String? description,
    String? emoji,
    required String userId,
    required String displayName,
    String? photoUrl,
    bool showProfilePhoto = true,
  }) async {
    final code = newInviteCode();
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
    batch.set(groupRef, GroupMapper.toFirestore(group));
    batch.set(groupRef.collection('members').doc(userId), {
      'uid': userId,
      'displayName': displayName,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
      'photoUrl': photoUrl,
      'showProfilePhoto': showProfilePhoto,
    });
    batch.set(_db.collection('invite_codes').doc(code), {
      'groupId': groupRef.id,
      'groupName': name,
      'groupEmoji': emoji,
    });
    await batch.commit();

    return group;
  }

  @override
  Future<void> joinGroup(
    String groupId,
    String userId,
    String displayName, {
    String? photoUrl,
    bool showProfilePhoto = true,
  }) async {
    final groupRef = _db.collection('groups').doc(groupId);
    // BUG G5 corrigé : déjà membre → rien à écrire (le `set` sans merge
    // remettait le rôle à « member » et réinitialisait le pseudo). Un
    // non-membre n'a pas le droit de lire ce document : refus = pas membre.
    try {
      final existing = await groupRef.collection('members').doc(userId).get();
      if (existing.exists) return;
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
    final batch = _db.batch();
    batch.update(groupRef, {
      'memberIds': FieldValue.arrayUnion([userId]),
    });
    batch.set(groupRef.collection('members').doc(userId), {
      'uid': userId,
      'displayName': displayName,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
      'photoUrl': photoUrl,
      'showProfilePhoto': showProfilePhoto,
    });
    await batch.commit();
  }

  @override
  Future<Group?> joinGroupByCode(
    String code,
    String userId,
    String displayName, {
    String? photoUrl,
    bool showProfilePhoto = true,
  }) async {
    final codeDoc = await _db
        .collection('invite_codes')
        .doc(code.toUpperCase().trim())
        .get();
    if (!codeDoc.exists) return null;

    final groupId = codeDoc.data()!['groupId'] as String;

    await joinGroup(
      groupId,
      userId,
      displayName,
      photoUrl: photoUrl,
      showProfilePhoto: showProfilePhoto,
    );

    final updated = await _db.collection('groups').doc(groupId).get();
    if (!updated.exists) return null;
    return GroupMapper.fromFirestore(updated.id, updated.data()!);
  }

  @override
  Stream<List<GroupMember>> watchMembers(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .snapshots()
        .map(
          (snap) => mapDocsSafely(
            snap.docs,
            (_, data) => GroupMemberMapper.fromFirestore(data),
            label: 'watchMembers',
          ),
        )
        .surfacePermissionDenied('watchMembers');
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
  Future<void> leaveGroup(
    String groupId,
    String userId, {
    String? systemMessage,
  }) async {
    final groupRef = _db.collection('groups').doc(groupId);
    final batch = _db.batch();
    batch.update(groupRef, {
      'memberIds': FieldValue.arrayRemove([userId]),
    });
    batch.delete(groupRef.collection('members').doc(userId));
    if (systemMessage != null) {
      final msgRef = groupRef.collection('messages').doc();
      batch.set(msgRef, {
        'groupId': groupId,
        'senderId': userId,
        'senderName': null,
        'content': systemMessage,
        'type': 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'notifScreen': 'chat',
      });
    }
    await batch.commit();
  }

  @override
  Future<void> transferOwnership(
    String groupId,
    String currentOwnerId,
    String newOwnerId,
  ) async {
    final groupRef = _db.collection('groups').doc(groupId);
    final batch = _db.batch();
    batch.update(groupRef, {'createdBy': newOwnerId});
    batch.update(groupRef.collection('members').doc(newOwnerId), {
      'role': 'owner',
    });
    batch.update(groupRef.collection('members').doc(currentOwnerId), {
      'role': 'member',
    });
    await batch.commit();
  }

  @override
  Future<void> deleteGroup(String groupId, String? inviteCode) async {
    final batch = _db.batch();
    batch.delete(_db.collection('groups').doc(groupId));
    if (inviteCode != null) {
      batch.delete(_db.collection('invite_codes').doc(inviteCode));
    }
    await batch.commit();
  }

  @override
  Future<void> updateGroupInfo(
    String groupId, {
    required String name,
    String? description,
  }) async {
    await _db.collection('groups').doc(groupId).update({
      'name': name,
      'description': description,
    });
  }

  @override
  Future<String> generateInviteCode(String groupId) async {
    final groupDoc = await _db.collection('groups').doc(groupId).get();
    final groupData = groupDoc.data();
    final oldCode = groupData?['inviteCode'] as String?;
    final code = newInviteCode();
    final batch = _db.batch();
    // Régénération : l'ancien code est supprimé pour invalider les liens déjà
    // partagés (un seul code actif par groupe).
    if (oldCode != null && oldCode != code) {
      batch.delete(_db.collection('invite_codes').doc(oldCode));
    }
    batch.update(_db.collection('groups').doc(groupId), {'inviteCode': code});
    batch.set(_db.collection('invite_codes').doc(code), {
      'groupId': groupId,
      'groupName': groupData?['name'],
      'groupEmoji': groupData?['emoji'],
    });
    await batch.commit();
    return code;
  }

  @override
  Future<InvitePreview?> resolveInviteCode(String code) async {
    final codeDoc = await _db
        .collection('invite_codes')
        .doc(code.toUpperCase().trim())
        .get();
    if (!codeDoc.exists) return null;
    final data = codeDoc.data()!;
    final groupId = data['groupId'] as String;

    // La photo du groupe est lue en direct depuis Storage (chemin déterministe
    // `group_photos/<groupId>.jpg`, lisible par tout utilisateur connecté) :
    // toujours à jour, et accessible avant l'adhésion — contrairement au
    // document `groups`, réservé aux membres. Absente → on retombe sur l'emoji.
    String? photoUrl;
    try {
      photoUrl = await _storage
          .ref('group_photos/$groupId.jpg')
          .getDownloadURL();
    } catch (_) {
      photoUrl = null;
    }

    return InvitePreview(
      groupId: groupId,
      groupName: data['groupName'] as String?,
      groupEmoji: data['groupEmoji'] as String?,
      groupPhotoUrl: photoUrl,
    );
  }

  @override
  Future<void> updateGroupEmoji(String groupId, String emoji) => _db
      .collection(FirestoreCollections.groups)
      .doc(groupId)
      .update({GroupFields.emoji: emoji});

  @override
  Future<void> updateGroupPhotoUrl(String groupId, String? photoUrl) => _db
      .collection(FirestoreCollections.groups)
      .doc(groupId)
      .update({GroupFields.photoUrl: photoUrl});

  @override
  Future<void> updateMemberDisplayName(
    String groupId,
    String userId,
    String displayName,
  ) async {
    final membersRef = _db
        .collection('groups')
        .doc(groupId)
        .collection('members');
    final snapshot = await membersRef.get();
    final conflict = snapshot.docs.any(
      (doc) =>
          doc.id != userId &&
          (doc.data()['displayName'] as String?)?.toLowerCase() ==
              displayName.toLowerCase(),
    );
    if (conflict) {
      throw Exception('Ce pseudo est déjà utilisé dans ce groupe.');
    }
    await membersRef.doc(userId).update({'displayName': displayName});
  }
}
