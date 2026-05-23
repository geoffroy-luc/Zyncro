import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../domain/repositories/i_messages_repository.dart';
import '../../../../shared/models/message.dart';

class MessagesRepository implements IMessagesRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String groupId) =>
      _db.collection('groups').doc(groupId).collection('messages');

  CollectionReference<Map<String, dynamic>> _typingCol(String groupId) =>
      _db.collection('groups').doc(groupId).collection('typing');

  @override
  Stream<List<Message>> watchMessages(String groupId) {
    return _col(groupId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Message.fromMap(doc.id, doc.data()))
              .toList(),
        )
        .handleError(
          (_) {},
          test: (e) => e is FirebaseException && e.code == 'permission-denied',
        );
  }

  @override
  Stream<List<Message>> watchMediaMessages(String groupId) {
    return _col(groupId)
        .where('type', whereIn: ['image', 'file'])
        .snapshots()
        .map((snap) {
          final msgs = snap.docs
              .map((doc) => Message.fromMap(doc.id, doc.data()))
              .toList();
          msgs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return msgs;
        })
        .handleError(
          (_) {},
          test: (e) => e is FirebaseException && e.code == 'permission-denied',
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
    final staleThreshold = const Duration(seconds: 6);
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
    await ref.set(message.toMap());
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
    await ref.set({...message.toMap(), 'notifScreen': notifScreen});
  }

  @override
  Future<void> sendAudio({
    required String groupId,
    required String senderId,
    required String senderName,
    required String filePath,
    required int durationSeconds,
  }) async {
    final ref = _col(groupId).doc();
    final storageRef = FirebaseStorage.instance
        .ref('audio/$groupId/${ref.id}.m4a');
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
    );
    await ref.set(message.toMap());
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
    final ext = filePath.split('.').last;
    final ref = _col(groupId).doc();
    final storageRef = FirebaseStorage.instance
        .ref('media/$groupId/${ref.id}.$ext');
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
    await ref.set(message.toMap());
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
        final ext = media.filePath.split('.').last;
        final storageRef = FirebaseStorage.instance
            .ref('media/$groupId/${ref.id}_$index.$ext');
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
    await ref.set(message.toMap());
  }

  @override
  Future<void> sendPoll({
    required String groupId,
    required String senderId,
    required String senderName,
    required String question,
    required List<String> options,
    bool multipleChoice = false,
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
    );
    await ref.set(message.toMap());
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
  Stream<int> watchUnreadCount({
    required String groupId,
    required String userId,
  }) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(userId)
        .snapshots()
        .asyncExpand((memberSnap) {
          if (!memberSnap.exists) return Stream.value(0);
          final ts = memberSnap.data()?['lastReadAt'] as Timestamp?;
          if (ts == null) return Stream.value(0);
          return _col(groupId)
              .where('timestamp', isGreaterThan: ts)
              .snapshots()
              .map((snap) => snap.docs.length);
        });
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

      // En mode exclusif (choix unique), retire l'utilisateur de toutes les autres réactions
      if (exclusive) {
        for (final key in reactions.keys) {
          reactions[key]?.remove(userId);
        }
      }

      // Ajoute la nouvelle réaction sauf si l'utilisateur la retirait
      if (!hasReacted) {
        reactions[emoji] = [...(reactions[emoji] ?? []), userId];
      }

      // Supprime les listes vides
      reactions.removeWhere((_, v) => v.isEmpty);

      tx.update(ref, {'reactions': reactions});
    });
  }
}
