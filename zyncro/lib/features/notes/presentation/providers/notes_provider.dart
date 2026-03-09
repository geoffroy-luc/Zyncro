import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/notes_repository.dart';
import '../../domain/repositories/i_notes_repository.dart';
import '../../../../shared/models/note.dart';
import '../../../groups/presentation/providers/groups_provider.dart';

final notesRepositoryProvider = Provider<INotesRepository>(
  (_) => NotesRepository(),
);

final notesProvider = StreamProvider<List<Note>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return Stream.value([]);
  return ref.watch(notesRepositoryProvider).watchNotes(groupId);
});
