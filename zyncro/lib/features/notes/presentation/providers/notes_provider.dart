import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/notes/data/repositories/notes_repository.dart';
import 'package:zyncro/features/notes/domain/repositories/i_notes_repository.dart';
import 'package:zyncro/shared/models/note.dart';

final notesRepositoryProvider = Provider<INotesRepository>(
  (_) => NotesRepository(),
);

final notesProvider = StreamProvider<List<Note>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return Stream.value([]);
  return ref.watch(notesRepositoryProvider).watchNotes(groupId);
});
