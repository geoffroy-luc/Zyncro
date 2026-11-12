import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zyncro/core/utils/firestore_stream_extensions.dart';
import 'package:zyncro/features/notes/data/mappers/note_mapper.dart';
import 'package:zyncro/features/notes/domain/entities/note.dart';
import 'package:zyncro/features/notes/domain/repositories/notes_repository.dart';
import 'package:zyncro/shared/data/mappers/map_diff.dart';

class FirestoreNotesRepository implements NotesRepository {
  FirestoreNotesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String groupId) =>
      _db.collection('groups').doc(groupId).collection('notes');

  @override
  Stream<List<Note>> watchNotes(String groupId) {
    return _col(groupId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) {
          final notes = mapDocsSafely(
            snap.docs,
            NoteMapper.fromFirestore,
            label: 'watchNotes',
          );
          // Tri côté client : épinglées en premier, puis par date
          notes.sort((a, b) {
            if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
            return b.updatedAt.compareTo(a.updatedAt);
          });
          return notes;
        })
        .surfacePermissionDenied('watchNotes');
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
    await ref.set(NoteMapper.toFirestore(note));
    return note;
  }

  @override
  Future<void> updateNote(String groupId, Note note, {Note? from}) async {
    final after = NoteMapper.toFirestore(note);
    final changes = from == null
        ? after
        : changedEntries(NoteMapper.toFirestore(from), after);
    if (changes.isEmpty) return;
    await _col(groupId).doc(note.id).update(changes);
  }

  @override
  Future<void> deleteNote(String groupId, String noteId) async {
    await _col(groupId).doc(noteId).delete();
  }
}
