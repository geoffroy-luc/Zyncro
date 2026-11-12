import 'package:zyncro/features/auth/domain/entities/app_user.dart';

abstract interface class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> registerWithEmail(
    String email,
    String password,
    String displayName,
  );
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signInWithApple();
  Future<AppUser> signInAnonymously(String displayName);
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<void> updateDisplayName(String displayName);
  Future<void> deleteAccount();
}
