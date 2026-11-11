import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';
import 'package:zyncro/shared/data/mappers/firestore_codec.dart';

/// Champs Firestore d'un message (`groups/{gid}/messages/{id}`).
abstract final class MessageFields {
  static const groupId = 'groupId';
  static const senderId = 'senderId';
  static const senderName = 'senderName';
  static const content = 'content';
  static const type = 'type';
  static const timestamp = 'timestamp';
  static const editedAt = 'editedAt';
  static const reactions = 'reactions';
  static const replyToId = 'replyToId';
  static const replyToSenderName = 'replyToSenderName';
  static const replyToContent = 'replyToContent';
  static const notifScreen = 'notifScreen';
}

abstract final class MessageMapper {
  static Message fromFirestore(String id, Map<String, dynamic> map) {
    return Message(
      id: id,
      groupId: map[MessageFields.groupId] as String,
      senderId: map[MessageFields.senderId] as String?,
      senderName: map[MessageFields.senderName] as String?,
      content: map[MessageFields.content] as String,
      type: MessageType.values.byName(
        map[MessageFields.type] as String? ?? 'text',
      ),
      // null tant qu'un FieldValue.serverTimestamp() est en attente d'écriture
      // (cache local) : on estime avec l'horloge locale (BUGS_FOUND D2).
      timestamp:
          (map[MessageFields.timestamp] as Timestamp?)?.toDate() ??
          DateTime.now(),
      editedAt: FirestoreCodec.toDateOrNull(map[MessageFields.editedAt]),
      reactions: (map[MessageFields.reactions] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, List<String>.from(v as List<dynamic>))),
      replyToId: map[MessageFields.replyToId] as String?,
      replyToSenderName: map[MessageFields.replyToSenderName] as String?,
      replyToContent: map[MessageFields.replyToContent] as String?,
    );
  }

  static Map<String, dynamic> toFirestore(Message message) => {
    MessageFields.groupId: message.groupId,
    MessageFields.senderId: message.senderId,
    MessageFields.senderName: message.senderName,
    MessageFields.content: message.content,
    MessageFields.type: message.type.name,
    MessageFields.timestamp: FirestoreCodec.fromDate(message.timestamp),
    if (message.editedAt != null)
      MessageFields.editedAt: FirestoreCodec.fromDate(message.editedAt!),
    if (message.reactions.isNotEmpty)
      MessageFields.reactions: message.reactions,
    if (message.replyToId != null) MessageFields.replyToId: message.replyToId,
    if (message.replyToSenderName != null)
      MessageFields.replyToSenderName: message.replyToSenderName,
    if (message.replyToContent != null)
      MessageFields.replyToContent: message.replyToContent,
  };
}
