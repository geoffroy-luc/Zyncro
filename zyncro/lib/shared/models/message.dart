import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, system, image, file }

class Message {
  final String id;
  final String groupId;
  final String? senderId;
  final String? senderName;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final DateTime? editedAt;
  final Map<String, List<String>> reactions;

  const Message({
    required this.id,
    required this.groupId,
    this.senderId,
    this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
    this.editedAt,
    this.reactions = const {},
  });

  factory Message.fromMap(String id, Map<String, dynamic> map) {
    return Message(
      id: id,
      groupId: map['groupId'] as String,
      senderId: map['senderId'] as String?,
      senderName: map['senderName'] as String?,
      content: map['content'] as String,
      type: MessageType.values.byName(map['type'] as String? ?? 'text'),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      editedAt: map['editedAt'] == null
          ? null
          : (map['editedAt'] as Timestamp).toDate(),
      reactions: (map['reactions'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': type.name,
      'timestamp': Timestamp.fromDate(timestamp),
      if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
      if (reactions.isNotEmpty) 'reactions': reactions,
    };
  }
}
