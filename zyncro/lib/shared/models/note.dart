import 'package:cloud_firestore/cloud_firestore.dart';

class ChecklistItem {
  final String text;
  final bool done;

  const ChecklistItem({required this.text, this.done = false});

  factory ChecklistItem.fromMap(Map<String, dynamic> map) =>
      ChecklistItem(text: map['text'] as String, done: map['done'] as bool? ?? false);

  Map<String, dynamic> toMap() => {'text': text, 'done': done};

  ChecklistItem copyWith({String? text, bool? done}) =>
      ChecklistItem(text: text ?? this.text, done: done ?? this.done);
}

class Note {
  final String id;
  final String groupId;
  final String title;
  final String content;
  final bool isPinned;
  final String? color;
  final bool isChecklist;
  final List<ChecklistItem> checklist;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;

  const Note({
    required this.id,
    required this.groupId,
    required this.title,
    required this.content,
    required this.isPinned,
    this.color,
    this.isChecklist = false,
    this.checklist = const [],
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
  });

  factory Note.fromMap(String id, Map<String, dynamic> map) {
    final rawChecklist = map['checklist'] as List<dynamic>?;
    return Note(
      id: id,
      groupId: map['groupId'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      isPinned: map['isPinned'] as bool? ?? false,
      color: map['color'] as String?,
      isChecklist: map['isChecklist'] as bool? ?? false,
      checklist: rawChecklist
              ?.map((e) => ChecklistItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'title': title,
      'content': content,
      'isPinned': isPinned,
      'color': color,
      'isChecklist': isChecklist,
      'checklist': checklist.map((e) => e.toMap()).toList(),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  Note copyWith({
    String? title,
    String? content,
    bool? isPinned,
    String? color,
    bool? isChecklist,
    List<ChecklistItem>? checklist,
    String? updatedBy,
  }) {
    return Note(
      id: id,
      groupId: groupId,
      title: title ?? this.title,
      content: content ?? this.content,
      isPinned: isPinned ?? this.isPinned,
      color: color ?? this.color,
      isChecklist: isChecklist ?? this.isChecklist,
      checklist: checklist ?? this.checklist,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
