import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyncro/features/groups/data/repositories/firestore_groups_repository.dart';

class _NoStorage extends Mock implements FirebaseStorage {}

void main() {
  test('BUG G5 corrigé : rejoindre un groupe dont on est déjà membre ne '
      'réinitialise ni le rôle ni le pseudo', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('groups/g1').set({
      'name': 'Famille',
      'memberIds': ['owner'],
    });
    await db.doc('groups/g1/members/owner').set({
      'uid': 'owner',
      'displayName': 'Chef',
      'role': 'owner',
    });
    final repo = FirestoreGroupsRepository(db, _NoStorage());
    await repo.joinGroup('g1', 'owner', 'Autre pseudo');
    final member = (await db.doc('groups/g1/members/owner').get()).data()!;
    expect(member['role'], 'owner');
    expect(member['displayName'], 'Chef');

    await repo.joinGroup('g1', 'new', 'Nouveau');
    final added = (await db.doc('groups/g1/members/new').get()).data()!;
    expect(added['role'], 'member');
  });
}
