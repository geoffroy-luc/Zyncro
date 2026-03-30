import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Handles all profile-photo logic.
///
/// Data model:
///   Firestore users/{uid}:
///     photoUrl         – custom uploaded photo URL (null = no custom photo)
///     showProfilePhoto – whether to show any photo (false → show initials)
///
///   Effective display URL = customPhotoUrl ?? firebaseUser.photoURL
///   (Firebase Auth keeps the original Google / Apple photo URL forever.)
///
///   GroupMember docs store the *effective* photoUrl so they can be displayed
///   without extra reads.
class UserProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? get _user => _auth.currentUser;

  /// Provider photo (Google / Apple), always available via Firebase Auth.
  String? get providerPhotoUrl => _user?.photoURL;

  /// Streams the user doc so the UI can react to changes.
  Stream<Map<String, dynamic>?> watchUserDoc() {
    final uid = _user?.uid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) => s.data());
  }

  /// Picks an image from [source], uploads it to Storage, updates Firestore
  /// and propagates to all group member docs.
  Future<String> uploadPhoto(ImageSource source) async {
    final uid = _user?.uid;
    if (uid == null) throw Exception('Not authenticated');

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (file == null) throw Exception('cancelled');

    final ref = _storage.ref().child('profile_photos/$uid.jpg');
    await ref.putFile(
      File(file.path),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await ref.getDownloadURL();

    final showPhoto = await _getShowProfilePhoto(uid);
    await _db
        .collection('users')
        .doc(uid)
        .set({'photoUrl': url}, SetOptions(merge: true));

    final effective = showPhoto ? url : null;
    await _propagateToGroups(uid, effective, showPhoto);
    return url;
  }

  /// Resets to the provider photo (Google / Apple).
  /// Deletes the custom Storage photo if it exists.
  Future<void> resetToProviderPhoto() async {
    final uid = _user?.uid;
    if (uid == null) return;
    await _tryDeleteStoragePhoto(uid);

    final showPhoto = await _getShowProfilePhoto(uid);
    await _db
        .collection('users')
        .doc(uid)
        .set({'photoUrl': null}, SetOptions(merge: true));

    final effective = showPhoto ? _user?.photoURL : null;
    await _propagateToGroups(uid, effective, showPhoto);
  }

  /// Updates whether the photo is shown (false → show initials everywhere).
  Future<void> updateShowProfilePhoto(bool show) async {
    final uid = _user?.uid;
    if (uid == null) return;

    final customUrl = await _getCustomPhotoUrl(uid);
    final effective = show ? (customUrl ?? _user?.photoURL) : null;

    await _db
        .collection('users')
        .doc(uid)
        .set({'showProfilePhoto': show}, SetOptions(merge: true));
    await _propagateToGroups(uid, effective, show);
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  Future<String?> _getCustomPhotoUrl(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['photoUrl'] as String?;
  }

  Future<bool> _getShowProfilePhoto(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['showProfilePhoto'] as bool? ?? true;
  }

  Future<void> _propagateToGroups(
    String uid,
    String? effectivePhotoUrl,
    bool showProfilePhoto,
  ) async {
    final groupsSnap = await _db
        .collection('groups')
        .where('memberIds', arrayContains: uid)
        .get();
    if (groupsSnap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final g in groupsSnap.docs) {
      batch.update(
        g.reference.collection('members').doc(uid),
        {
          'photoUrl': effectivePhotoUrl,
          'showProfilePhoto': showProfilePhoto,
        },
      );
    }
    await batch.commit();
  }

  Future<void> _tryDeleteStoragePhoto(String uid) async {
    try {
      await _storage.ref().child('profile_photos/$uid.jpg').delete();
    } catch (_) {
      // File may not exist.
    }
  }
}
