import 'package:firebase_auth/firebase_auth.dart';

abstract interface class IAuthRepository {
  Stream<User?> get authStateChanges;
  Future<User> signInWithEmail(String email, String password);
  Future<User> registerWithEmail(
    String email,
    String password,
    String displayName,
  );
  Future<User> signInWithGoogle();
  Future<User> signInAnonymously();
  Future<void> signOut();
  Future<void> resetPassword(String email);
}
