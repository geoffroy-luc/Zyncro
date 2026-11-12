import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/core/firebase/firebase_providers.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/notes/data/repositories/firestore_notes_repository.dart';
import 'package:zyncro/features/notes/domain/entities/note.dart';
import 'package:zyncro/features/notes/domain/repositories/notes_repository.dart';

final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => FirestoreNotesRepository(ref.watch(firestoreProvider)),
);

final notesProvider = StreamProvider<List<Note>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return Stream.value([]);
  return ref.watch(notesRepositoryProvider).watchNotes(groupId);
});
