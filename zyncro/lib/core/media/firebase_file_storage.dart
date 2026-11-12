import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:zyncro/core/media/file_storage.dart';

class FirebaseFileStorage implements FileStorage {
  FirebaseFileStorage(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<String> upload(
    String localPath,
    String storagePath, {
    required String contentType,
  }) async {
    final ref = _storage.ref().child(storagePath);
    await ref.putFile(
      File(localPath),
      SettableMetadata(contentType: contentType),
    );
    return ref.getDownloadURL();
  }

  @override
  Future<void> delete(String storagePath) =>
      _storage.ref().child(storagePath).delete();
}
