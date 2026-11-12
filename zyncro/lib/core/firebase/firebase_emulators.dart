import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Branchement OPTIONNEL sur les émulateurs Firebase locaux (outillage de
/// test de bout en bout, docs/refactor/PLAN.md §5).
///
/// Inactif par défaut : il faut compiler avec
/// `--dart-define=USE_FIREBASE_EMULATORS=true`. La constante étant évaluée à
/// la compilation, ce code est éliminé des builds de production.
const bool useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
);

/// Hôte des émulateurs vu depuis l'appareil (10.0.2.2 = machine hôte depuis
/// l'émulateur Android).
const String _emulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

Future<void> connectFirebaseEmulatorsIfRequested() async {
  if (!useFirebaseEmulators) return;
  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
  await FirebaseStorage.instance.useStorageEmulator(_emulatorHost, 9199);
  FirebaseFunctions.instance.useFunctionsEmulator(_emulatorHost, 5001);
}
