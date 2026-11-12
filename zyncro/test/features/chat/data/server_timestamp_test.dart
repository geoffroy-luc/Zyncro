import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyncro/features/chat/data/repositories/firestore_messages_repository.dart';

class _NoStorage extends Mock implements FirebaseStorage {}

void main() {
  test('BUG K4 corrigé : horodatage serveur pour un nouveau message', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreMessagesRepository(db, _NoStorage());
    await repo.sendMessage(
      groupId: 'g1',
      senderId: 'a',
      senderName: 'A',
      content: 'Salut',
    );
    await repo.sendSystemMessage(
      groupId: 'g1',
      userId: 'a',
      content: 'Système',
      notifScreen: 'chat',
    );
    final docs = (await db.collection('groups/g1/messages').get()).docs;
    expect(docs, hasLength(2));
    // La sentinelle serverTimestamp est résolue à l'écriture (par le faux
    // Firestore ici, par le serveur en vrai) : l'écriture aboutit avec un
    // Timestamp. Le bout en bout le vérifie contre l'émulateur.
    for (final d in docs) {
      expect(d.data()['timestamp'], isA<Timestamp>());
    }
  });
}
