enum MessageType { text, system, image, file, poll, audio }

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
  final String? replyToId;
  final String? replyToSenderName;
  final String? replyToContent;

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
    this.replyToId,
    this.replyToSenderName,
    this.replyToContent,
  });
}
