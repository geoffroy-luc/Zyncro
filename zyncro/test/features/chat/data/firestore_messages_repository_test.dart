import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyncro/features/chat/data/repositories/firestore_messages_repository.dart';
import 'package:zyncro/features/chat/domain/repositories/messages_repository.dart';

class _NoStorage extends Mock implements FirebaseStorage {}

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreMessagesRepository repo;
  final t0 = DateTime(2026, 11, 1, 12);

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreMessagesRepository(db, _NoStorage());
  });

  Future<void> add(String id, String type, int minutes) =>
      db.collection('groups/g1/messages').doc(id).set({
        'groupId': 'g1',
        'senderId': 'a',
        'content': '{}',
        'type': type,
        'timestamp': Timestamp.fromDate(t0.add(Duration(minutes: minutes))),
      });

  test(
    'aperçu médias : les N plus récents, photos et vidéos seulement',
    () async {
      for (var i = 0; i < 8; i++) {
        await add('img$i', i.isEven ? 'image' : 'file', i);
      }
      await add('txt', 'text', 100);
      final recent = await repo.watchRecentMediaMessages('g1', limit: 6).first;
      expect(recent.map((m) => m.id), [
        'img7',
        'img6',
        'img5',
        'img4',
        'img3',
        'img2',
      ]);
    },
  );

  test(
    'non-lus plafonnés à unreadCountCap (badge « 99+ » identique)',
    () async {
      for (var i = 0; i < unreadCountCap + 20; i++) {
        await add('m$i', 'text', i);
      }
      final count = await repo
          .watchCountSince(
            groupId: 'g1',
            since: t0.subtract(const Duration(minutes: 1)),
          )
          .first;
      expect(count, unreadCountCap);
      expect(count > 99, isTrue);
    },
  );

  test('non-lus sous le plafond : nombre exact', () async {
    for (var i = 0; i < 5; i++) {
      await add('m$i', 'text', i);
    }
    final count = await repo
        .watchCountSince(
          groupId: 'g1',
          since: t0.add(const Duration(minutes: 1)),
        )
        .first;
    expect(count, 3);
  });
}
