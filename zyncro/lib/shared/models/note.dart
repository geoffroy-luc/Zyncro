import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String groupId;
  final String title;
  final String content;
  final bool isPinned;
  final String? color;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.groupId,
    required this.title,
    required this.content,
    required this.isPinned,
    this.color,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromMap(String id, Map<String, dynamic> map) {
    return Note(
      id: id,
      groupId: map['groupId'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      isPinned: map['isPinned'] as bool? ?? false,
      color: map['color'] as String?,
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'title': title,
      'content': content,
      'isPinned': isPinned,
      'color': color,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Note copyWith({
    String? title,
    String? content,
    bool? isPinned,
    String? color,
  }) {
    return Note(
      id: id,
      groupId: groupId,
      title: title ?? this.title,
      content: content ?? this.content,
      isPinned: isPinned ?? this.isPinned,
      color: color ?? this.color,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
