import '../../../../shared/models/note.dart';

abstract interface class INotesRepository {
  Stream<List<Note>> watchNotes(String groupId);
  Future<Note> createNote({
    required String groupId,
    required String title,
    required String content,
    bool isPinned,
    String? color,
    required String userId,
  });
  Future<void> updateNote(String groupId, Note note);
  Future<void> deleteNote(String groupId, String noteId);
}
