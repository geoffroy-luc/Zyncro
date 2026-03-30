import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/user_profile_service.dart';
import '../../domain/repositories/i_auth_repository.dart';

final authRepositoryProvider = Provider<IAuthRepository>(
  (_) => AuthRepository(),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.read(authRepositoryProvider).authStateChanges,
);

final userProfileServiceProvider = Provider<UserProfileService>(
  (_) => UserProfileService(),
);

/// Streams the current user's Firestore doc (photoUrl, showProfilePhoto, etc.)
/// Re-subscribes automatically when the auth state changes.
final userDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  // Watch auth state so this provider rebuilds on login/logout.
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(userProfileServiceProvider).watchUserDoc();
});
