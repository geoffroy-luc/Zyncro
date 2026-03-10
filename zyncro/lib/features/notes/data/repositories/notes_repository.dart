import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/i_notes_repository.dart';
import '../../../../shared/models/note.dart';

class NotesRepository implements INotesRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String groupId) =>
      _db.collection('groups').doc(groupId).collection('notes');

  @override
  Stream<List<Note>> watchNotes(String groupId) {
    return _col(groupId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) {
          final notes = snap.docs
              .map((doc) => Note.fromMap(doc.id, doc.data()))
              .toList();
          // Tri côté client : épinglées en premier, puis par date
          notes.sort((a, b) {
            if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
            return b.updatedAt.compareTo(a.updatedAt);
          });
          return notes;
        });
  }

  @override
  Future<Note> createNote({
    required String groupId,
    required String title,
    required String content,
    bool isPinned = false,
    String? color,
    bool isChecklist = false,
    List<ChecklistItem> checklist = const [],
    required String userId,
  }) async {
    final ref = _col(groupId).doc();
    final now = DateTime.now();
    final note = Note(
      id: ref.id,
      groupId: groupId,
      title: title,
      content: content,
      isPinned: isPinned,
      color: color,
      isChecklist: isChecklist,
      checklist: checklist,
      createdBy: userId,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(note.toMap());
    return note;
  }

  @override
  Future<void> updateNote(String groupId, Note note) async {
    await _col(groupId).doc(note.id).update(note.toMap());
  }

  @override
  Future<void> deleteNote(String groupId, String noteId) async {
    await _col(groupId).doc(noteId).delete();
  }
}
