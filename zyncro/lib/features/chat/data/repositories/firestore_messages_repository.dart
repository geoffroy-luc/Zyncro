import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:zyncro/core/firebase/firestore_paths.dart';
import 'package:zyncro/core/media/file_extension.dart';
import 'package:zyncro/core/utils/firestore_stream_extensions.dart';
import 'package:zyncro/features/chat/data/mappers/message_mapper.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';
import 'package:zyncro/features/chat/domain/reactions.dart';
import 'package:zyncro/features/chat/domain/repositories/messages_repository.dart';
import 'package:zyncro/features/groups/data/mappers/group_member_mapper.dart';

class FirestoreMessagesRepository implements MessagesRepository {
  FirestoreMessagesRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _col(String groupId) =>
      _db.collection('groups').doc(groupId).collection('messages');

  CollectionReference<Map<String, dynamic>> _typingCol(String groupId) =>
      _db.collection('groups').doc(groupId).collection('typing');

  @override
  Stream<List<Message>> watchMessages(String groupId) {
    return _col(groupId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => mapDocsSafely(
            snap.docs,
            MessageMapper.fromFirestore,
            label: 'watchMessages',
          ),
        )
        .surfacePermissionDenied('watchMessages');
  }

  @override
  Future<List<Message>> fetchMessagesBefore(
    String groupId,
    DateTime before, {
    int limit = 50,
  }) async {
    final snap = await _col(groupId)
        .orderBy('timestamp', descending: true)
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(before))
        .limit(limit)
        .get();
    return mapDocsSafely(
      snap.docs,
      MessageMapper.fromFirestore,
      label: 'fetchMessagesBefore',
    );
  }

  @override
  Stream<List<Message>> watchRecentMediaMessages(
    String groupId, {
    required int limit,
  }) {
    return _col(groupId)
        .where(MessageFields.type, whereIn: ['image', 'file'])
        .orderBy(MessageFields.timestamp, descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => mapDocsSafely(
            snap.docs,
            MessageMapper.fromFirestore,
            label: 'watchRecentMediaMessages',
          ),
        )
        .surfacePermissionDenied('watchRecentMediaMessages');
  }

  @override
  Future<List<Message>> fetchMediaMessagesBefore(
    String groupId,
    DateTime before, {
    required int limit,
  }) async {
    final snap = await _col(groupId)
        .where(MessageFields.type, whereIn: ['image', 'file'])
        .orderBy(MessageFields.timestamp, descending: true)
        .where(
          MessageFields.timestamp,
          isLessThanOrEqualTo: Timestamp.fromDate(before),
        )
        .limit(limit)
        .get();
    return mapDocsSafely(
      snap.docs,
      MessageMapper.fromFirestore,
      label: 'fetchMediaMessagesBefore',
    );
  }

  @override
  Future<void> setTyping({
    required String groupId,
    required String userId,
    required String userName,
  }) async {
    try {
      await _typingCol(groupId).doc(userId).set({
        'name': userName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      // Permissions pas encore déployées — on ignore silencieusement
    }
  }

  @override
  Future<void> clearTyping({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _typingCol(groupId).doc(userId).delete();
    } on FirebaseException {
      // Permissions pas encore déployées — on ignore silencieusement
    }
  }

  @override
  Stream<List<String>> watchTyping({
    required String groupId,
    required String currentUserId,
  }) {
    const staleThreshold = Duration(seconds: 6);
    return _typingCol(groupId)
        .snapshots()
        .map((snap) {
          final now = DateTime.now();
          return snap.docs
              .where((doc) => doc.id != currentUserId)
              .where((doc) {
                final ts = doc.data()['updatedAt'];
                if (ts == null) return false;
                final updated = (ts as Timestamp).toDate();
                return now.difference(updated) < staleThreshold;
              })
              .map((doc) => doc.data()['name'] as String? ?? 'Quelqu\'un')
              .toList();
        })
        .handleError((_) => <String>[]);
  }

  @override
  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String content,
    String? replyToId,
    String? replyToSenderName,
    String? replyToContent,
  }) async {
    final ref = _col(groupId).doc();
    final message = Message(
      id: ref.id,
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: MessageType.text,
      timestamp: DateTime.now(),
      replyToId: replyToId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
    );
    await ref.set(MessageMapper.toFirestore(message));
  }

  @override
  Future<void> editMessage({
    required String groupId,
    required String messageId,
    required String content,
  }) async {
    await _col(groupId).doc(messageId).update({
      'content': content,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteMessage({
    required String groupId,
    required String messageId,
  }) async {
    await _col(groupId).doc(messageId).delete();
  }

  @override
  Future<void> sendSystemMessage({
    required String groupId,
    required String userId,
    required String content,
    required String notifScreen,
  }) async {
    final ref = _col(groupId).doc();
    final message = Message(
      id: ref.id,
      groupId: groupId,
      senderId: userId,
      content: content,
      type: MessageType.system,
      timestamp: DateTime.now(),
    );
    await ref.set({
      ...MessageMapper.toFirestore(message),
      'notifScreen': notifScreen,
    });
  }

  @override
  Future<void> sendAudio({
    required String groupId,
    required String senderId,
    required String senderName,
    required String filePath,
    required int durationSeconds,
    String? replyToId,
    String? replyToSenderName,
    String? replyToContent,
  }) async {
    final ref = _col(groupId).doc();
    final storageRef = _storage.ref('audio/$groupId/${ref.id}.m4a');
    final snapshot = await storageRef.putFile(
      File(filePath),
      SettableMetadata(contentType: 'audio/m4a'),
    );
    if (snapshot.state != TaskState.success) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        message: 'Upload failed with state: ${snapshot.state}',
      );
    }
    final url = await storageRef.getDownloadURL();

    final content = jsonEncode({'url': url, 'duration': durationSeconds});
    final message = Message(
      id: ref.id,
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: MessageType.audio,
      timestamp: DateTime.now(),
      replyToId: replyToId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
    );
    await ref.set(MessageMapper.toFirestore(message));
  }

  @override
  Future<void> sendMedia({
    required String groupId,
    required String senderId,
    required String senderName,
    required String filePath,
    required String mimeType,
    String? replyToId,
    String? replyToSenderName,
    String? replyToContent,
  }) async {
    final isVideo = mimeType.startsWith('video/');
    final ext = uploadExtension(filePath, mimeType);
    final ref = _col(groupId).doc();
    final storageRef = _storage.ref('media/$groupId/${ref.id}.$ext');
    final snapshot = await storageRef.putFile(
      File(filePath),
      SettableMetadata(contentType: mimeType),
    );
    if (snapshot.state != TaskState.success) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        message: 'Upload failed with state: ${snapshot.state}',
      );
    }
    final url = await storageRef.getDownloadURL();
    final content = jsonEncode({'url': url, 'mimeType': mimeType});
    final message = Message(
      id: ref.id,
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: isVideo ? MessageType.file : MessageType.image,
      timestamp: DateTime.now(),
      replyToId: replyToId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
    );
    await ref.set(MessageMapper.toFirestore(message));
  }

  @override
  Future<void> sendMultipleMedia({
    required String groupId,
    required String senderId,
    required String senderName,
    required List<({String filePath, String mimeType})> medias,
    String? replyToId,
    String? replyToSenderName,
    String? replyToContent,
  }) async {
    final ref = _col(groupId).doc();
    final results = await Future.wait(
      medias.asMap().entries.map((entry) async {
        final index = entry.key;
        final media = entry.value;
        final ext = uploadExtension(media.filePath, media.mimeType);
        final storageRef = _storage.ref('media/$groupId/${ref.id}_$index.$ext');
        final snapshot = await storageRef.putFile(
          File(media.filePath),
          SettableMetadata(contentType: media.mimeType),
        );
        if (snapshot.state != TaskState.success) {
          throw FirebaseException(
            plugin: 'firebase_storage',
            message: 'Upload failed with state: ${snapshot.state}',
          );
        }
        final url = await storageRef.getDownloadURL();
        return {'url': url, 'mimeType': media.mimeType};
      }),
    );

    final hasVideo = medias.any((m) => m.mimeType.startsWith('video/'));
    final content = jsonEncode({'medias': results});
    final message = Message(
      id: ref.id,
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: hasVideo ? MessageType.file : MessageType.image,
      timestamp: DateTime.now(),
      replyToId: replyToId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
    );
    await ref.set(MessageMapper.toFirestore(message));
  }

  @override
  Future<void> sendPoll({
    required String groupId,
    required String senderId,
    required String senderName,
    required String question,
    required List<String> options,
    bool multipleChoice = false,
    String? replyToId,
    String? replyToSenderName,
    String? replyToContent,
  }) async {
    final ref = _col(groupId).doc();
    final content = jsonEncode({
      'question': question,
      'options': options,
      'multipleChoice': multipleChoice,
    });
    final message = Message(
      id: ref.id,
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: MessageType.poll,
      timestamp: DateTime.now(),
      replyToId: replyToId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
    );
    await ref.set(MessageMapper.toFirestore(message));
  }

  @override
  Future<void> editPoll({
    required String groupId,
    required String messageId,
    required String question,
    required List<String> options,
    bool multipleChoice = false,
  }) async {
    final content = jsonEncode({
      'question': question,
      'options': options,
      'multipleChoice': multipleChoice,
    });
    await _col(groupId).doc(messageId).update({
      'content': content,
      'reactions': {},
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markAsRead({
    required String groupId,
    required String userId,
    required String messageId,
    required DateTime messageTimestamp,
  }) async {
    try {
      await _db
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(userId)
          .update({
            'lastReadMessageId': messageId,
            'lastReadAt': Timestamp.fromDate(messageTimestamp),
          });
    } on FirebaseException {
      // Silencieux — non bloquant
    }
  }

  @override
  Future<void> markGroupAsRead({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _db
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(userId)
          .update({'lastReadAt': Timestamp.now()});
    } on FirebaseException {
      // Silencieux — non bloquant
    }
  }

  @override
  Stream<DateTime?> watchLastReadAt({
    required String groupId,
    required String userId,
  }) {
    return _db
        .collection(FirestoreCollections.groups)
        .doc(groupId)
        .collection(FirestoreCollections.members)
        .doc(userId)
        .snapshots()
        .map((snap) {
          final ts = snap.data()?[GroupMemberFields.lastReadAt] as Timestamp?;
          return ts?.toDate();
        });
  }

  @override
  Stream<int> watchCountSince({
    required String groupId,
    required DateTime since,
  }) {
    return _col(groupId)
        .where(
          MessageFields.timestamp,
          isGreaterThan: Timestamp.fromDate(since),
        )
        .limit(unreadCountCap)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  @override
  Future<void> toggleReaction({
    required String groupId,
    required String messageId,
    required String emoji,
    required String userId,
    required bool hasReacted,
    bool exclusive = true,
  }) async {
    final ref = _col(groupId).doc(messageId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final reactions = (data['reactions'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      );

      final next = applyReaction(
        reactions,
        key: emoji,
        userId: userId,
        hasReacted: hasReacted,
        exclusive: exclusive,
      );
      tx.update(ref, {'reactions': next});
    });
  }
}
