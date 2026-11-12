import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/notes/data/mappers/note_mapper.dart';
import 'package:zyncro/features/notes/data/repositories/firestore_notes_repository.dart';
import 'package:zyncro/features/notes/domain/entities/note.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreNotesRepository repo;
  final t0 = DateTime(2026, 11, 1, 12);

  final note = Note(
    id: 'n1',
    groupId: 'g1',
    title: 'Courses',
    content: 'Pain',
    isPinned: false,
    createdBy: 'a',
    createdAt: t0,
    updatedAt: t0,
  );

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = FirestoreNotesRepository(db);
    await db.doc('groups/g1/notes/n1').set(NoteMapper.toFirestore(note));
  });

  Future<Map<String, dynamic>> stored() async =>
      (await db.doc('groups/g1/notes/n1').get()).data()!;

  test(
    'BUG G11 corrigé : une modification concurrente n’est pas écrasée',
    () async {
      // Un autre membre change le contenu pendant que l'on édite le titre.
      await db.doc('groups/g1/notes/n1').update({'content': 'Pain, lait'});
      await repo.updateNote(
        'g1',
        note.copyWith(title: 'Courses samedi', updatedBy: 'b'),
        from: note,
      );
      final data = await stored();
      expect(data['title'], 'Courses samedi');
      expect(data['content'], 'Pain, lait');
    },
  );

  test('BUG G11 corrigé : épingler ne touche que isPinned', () async {
    await repo.updateNote(
      'g1',
      note.copyWith(isPinned: true, touch: false),
      from: note,
    );
    final data = await stored();
    expect(data['isPinned'], isTrue);
    expect((data['updatedAt'] as Timestamp).toDate(), t0);
  });
}
