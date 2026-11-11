import 'package:zyncro/features/notes/domain/entities/note.dart';
import 'package:zyncro/shared/data/mappers/firestore_codec.dart';

/// Champs Firestore d'une note (`groups/{gid}/notes/{id}`).
abstract final class NoteFields {
  static const groupId = 'groupId';
  static const title = 'title';
  static const content = 'content';
  static const isPinned = 'isPinned';
  static const color = 'color';
  static const isChecklist = 'isChecklist';
  static const checklist = 'checklist';
  static const createdBy = 'createdBy';
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';
  static const updatedBy = 'updatedBy';
  static const itemText = 'text';
  static const itemDone = 'done';
}

abstract final class NoteMapper {
  static Note fromFirestore(String id, Map<String, dynamic> map) {
    final rawChecklist = map[NoteFields.checklist] as List<dynamic>?;
    return Note(
      id: id,
      groupId: map[NoteFields.groupId] as String,
      title: map[NoteFields.title] as String,
      content: map[NoteFields.content] as String,
      isPinned: map[NoteFields.isPinned] as bool? ?? false,
      color: map[NoteFields.color] as String?,
      isChecklist: map[NoteFields.isChecklist] as bool? ?? false,
      checklist:
          rawChecklist
              ?.map(
                (e) => checklistItemFromFirestore(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      createdBy: map[NoteFields.createdBy] as String,
      createdAt: FirestoreCodec.toDate(map[NoteFields.createdAt]),
      updatedAt: FirestoreCodec.toDate(map[NoteFields.updatedAt]),
      updatedBy: map[NoteFields.updatedBy] as String?,
    );
  }

  static Map<String, dynamic> toFirestore(Note note) => {
    NoteFields.groupId: note.groupId,
    NoteFields.title: note.title,
    NoteFields.content: note.content,
    NoteFields.isPinned: note.isPinned,
    NoteFields.color: note.color,
    NoteFields.isChecklist: note.isChecklist,
    NoteFields.checklist: note.checklist.map(checklistItemToFirestore).toList(),
    NoteFields.createdBy: note.createdBy,
    NoteFields.createdAt: FirestoreCodec.fromDate(note.createdAt),
    NoteFields.updatedAt: FirestoreCodec.fromDate(note.updatedAt),
    if (note.updatedBy != null) NoteFields.updatedBy: note.updatedBy,
  };

  static ChecklistItem checklistItemFromFirestore(Map<String, dynamic> map) =>
      ChecklistItem(
        text: map[NoteFields.itemText] as String,
        done: map[NoteFields.itemDone] as bool? ?? false,
      );

  static Map<String, dynamic> checklistItemToFirestore(ChecklistItem item) => {
    NoteFields.itemText: item.text,
    NoteFields.itemDone: item.done,
  };
}
