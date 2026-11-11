import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zyncro/core/firebase/firestore_paths.dart';
import 'package:zyncro/core/notifications/push_token_repository.dart';

/// ⚠️ Un seul token par utilisateur (multi-appareil non géré, BUGS_FOUND G17).
class FirestorePushTokenRepository implements PushTokenRepository {
  FirestorePushTokenRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection(FirestoreCollections.users).doc(uid);

  @override
  Future<void> saveToken(String uid, String token) => _user(uid).set({
    'fcmToken': token,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  @override
  Future<void> saveTokenOnly(String uid, String token) =>
      _user(uid).set({'fcmToken': token}, SetOptions(merge: true));

  @override
  Future<void> clearToken(String uid) => _user(uid).update({'fcmToken': null});
}
