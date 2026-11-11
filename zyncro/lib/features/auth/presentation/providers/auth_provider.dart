import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/core/firebase/firebase_providers.dart';
import 'package:zyncro/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:zyncro/features/auth/data/services/user_profile_service.dart';
import 'package:zyncro/features/auth/domain/entities/app_user.dart';
import 'package:zyncro/features/auth/domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(ref.watch(firebaseAuthProvider)),
);

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.read(authRepositoryProvider).authStateChanges,
);

final userProfileServiceProvider = Provider<UserProfileService>(
  (ref) => UserProfileService(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  ),
);

/// Streams the current user's Firestore doc (photoUrl, showProfilePhoto, etc.)
/// Re-subscribes automatically when the auth state changes.
final userDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  // Watch auth state so this provider rebuilds on login/logout.
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(userProfileServiceProvider).watchUserDoc();
});
