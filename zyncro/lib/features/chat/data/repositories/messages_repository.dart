import 'package:cloud_firestore/cloud_firestore.dart';
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
}
