import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/core/utils/firestore_stream_extensions.dart';
import 'package:zyncro/shared/models/event.dart';
import 'package:zyncro/shared/models/expense.dart';
import 'package:zyncro/shared/models/message.dart';
import 'package:zyncro/shared/models/note.dart';

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> docsOf(
    String col,
  ) async => (await db.collection(col).get()).docs;

  group('mapDocsSafely (BUGS_FOUND D1)', () {
    test(
      'un document malformé est ignoré, les autres sont conservés',
      () async {
        final col = db.collection('groups/g1/expenses');
        await col.doc('ok').set({
          'groupId': 'g1',
          'title': 'Courses',
          'amount': 12.5,
          'paidBy': 'a',
          'splitWith': ['a', 'b'],
          'date': Timestamp.now(),
          'createdBy': 'a',
          'createdAt': Timestamp.now(),
        });
        await col.doc('montant-texte').set({
          'groupId': 'g1',
          'title': 'x',
          'amount': 'beaucoup',
          'paidBy': 'a',
          'date': Timestamp.now(),
          'createdBy': 'a',
          'createdAt': Timestamp.now(),
        });
        await col.doc('enum-futur').set({
          'groupId': 'g1',
          'title': 'y',
          'amount': 3,
          'paidBy': 'a',
          'date': Timestamp.now(),
          'createdBy': 'a',
          'createdAt': Timestamp.now(),
          'expenseType': 'subscription',
        });

        final expenses = mapDocsSafely(
          await docsOf('groups/g1/expenses'),
          Expense.fromMap,
          label: 'test',
        );
        expect(expenses.map((e) => e.id), ['ok']);
      },
    );

    test('événements et notes : champ obligatoire manquant ignoré', () async {
      await db.collection('e').doc('sans-date').set({
        'groupId': 'g',
        'title': 't',
      });
      await db.collection('e').doc('ok').set({
        'groupId': 'g',
        'title': 't',
        'startDate': Timestamp.now(),
        'createdBy': 'a',
        'createdAt': Timestamp.now(),
      });
      expect(
        mapDocsSafely(
          await docsOf('e'),
          Event.fromMap,
          label: 't',
        ).map((e) => e.id),
        ['ok'],
      );

      await db.collection('n').doc('titre-nombre').set({
        'groupId': 'g',
        'title': 42,
        'content': '',
        'createdBy': 'a',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      expect(
        mapDocsSafely(await docsOf('n'), Note.fromMap, label: 't'),
        isEmpty,
      );
    });

    test('ordre des documents préservé', () async {
      for (final id in ['a', 'b', 'c']) {
        await db.collection('m').doc(id).set({
          'groupId': 'g',
          'content': id,
          'type': 'text',
          'timestamp': Timestamp.now(),
        });
      }
      final ids = mapDocsSafely(
        await docsOf('m'),
        Message.fromMap,
        label: 't',
      ).map((m) => m.id);
      expect(ids, ['a', 'b', 'c']);
    });
  });

  group('Message.fromMap (BUGS_FOUND D2)', () {
    test('timestamp serveur en attente (null) → estimé localement', () {
      final before = DateTime.now();
      final message = Message.fromMap('m1', {
        'groupId': 'g1',
        'senderId': 'a',
        'content': 'a quitté le groupe',
        'type': 'system',
        'timestamp': null,
      });
      expect(message.timestamp.isBefore(before), isFalse);
    });

    test('timestamp présent → inchangé', () {
      final ts = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
      final message = Message.fromMap('m1', {
        'groupId': 'g1',
        'content': 'x',
        'type': 'text',
        'timestamp': ts,
      });
      expect(message.timestamp, ts.toDate());
    });
  });
}
