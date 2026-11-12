class ChecklistItem {
  final String text;
  final bool done;

  const ChecklistItem({required this.text, this.done = false});

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

  Note copyWith({
    String? title,
    String? content,
    bool? isPinned,
    String? color,
    bool? isChecklist,
    List<ChecklistItem>? checklist,
    String? updatedBy,
    // false : ne pas dater la modification (épingler n'est pas modifier,
    // BUG G11 corrigé).
    bool touch = true,
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
      updatedAt: touch ? DateTime.now() : updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
