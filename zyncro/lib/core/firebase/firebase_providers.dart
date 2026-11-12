import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Point d'accès UNIQUE aux instances Firebase de l'app.
//
// Les repositories et services les reçoivent par constructeur : en test, on
// surcharge ces providers (FakeFirebaseFirestore, mocks…) sans toucher au code.

final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

final firebaseStorageProvider = Provider<FirebaseStorage>(
  (_) => FirebaseStorage.instance,
);

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (_) => FirebaseAuth.instance,
);

final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (_) => FirebaseMessaging.instance,
);
