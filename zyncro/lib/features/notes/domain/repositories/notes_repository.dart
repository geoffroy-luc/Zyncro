import 'package:zyncro/features/notes/domain/entities/note.dart';

abstract interface class NotesRepository {
  Stream<List<Note>> watchNotes(String groupId);
  Future<Note> createNote({
    required String groupId,
    required String title,
    required String content,
    bool isPinned,
    String? color,
    bool isChecklist,
    List<ChecklistItem> checklist,
    required String userId,
  });
  Future<void> updateNote(String groupId, Note note);
  Future<void> deleteNote(String groupId, String noteId);
}
