import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:zyncro/core/services/notification_service.dart';
import 'package:zyncro/features/auth/domain/entities/app_user.dart';
import 'package:zyncro/features/auth/domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, {GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  @override
  Stream<AppUser?> get authStateChanges => _auth.authStateChanges().map(
    (user) => user == null ? null : _toAppUser(user),
  );

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _toAppUser(user);
  }

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _toAppUser(credential.user!);
  }

  @override
  Future<AppUser> registerWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user!.updateDisplayName(displayName);
    return _toAppUser(credential.user!);
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(code: 'sign-in-cancelled');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return _toAppUser(result.user!);
  }

  @override
  Future<AppUser> signInWithApple() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    final result = await _auth.signInWithProvider(provider);
    return _toAppUser(result.user!);
  }

  @override
  Future<AppUser> signInAnonymously(String displayName) async {
    final credential = await _auth.signInAnonymously();
    await credential.user!.updateDisplayName(displayName.trim());
    await credential.user!.reload();
    return _toAppUser(_auth.currentUser!);
  }

  @override
  Future<void> signOut() async {
    await NotificationService.removeToken();
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  @override
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    await _auth.currentUser?.updateDisplayName(displayName.trim());
  }

  @override
  Future<void> deleteAccount() async {
    await NotificationService.removeToken();
    await _googleSignIn.signOut();
    await _auth.currentUser?.delete();
  }

  /// Frontière data → domaine : le `User` Firebase ne sort pas de cette couche.
  static AppUser _toAppUser(User user) => AppUser(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    photoUrl: user.photoURL,
    isAnonymous: user.isAnonymous,
  );
}
