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

  /// Avec [from] (état lu par l'appelant), seuls les champs modifiés sont
  /// écrits : une modification concurrente d'un autre membre n'est plus
  /// écrasée (BUG G11 corrigé).
  Future<void> updateNote(String groupId, Note note, {Note? from});
  Future<void> deleteNote(String groupId, String noteId);
}
