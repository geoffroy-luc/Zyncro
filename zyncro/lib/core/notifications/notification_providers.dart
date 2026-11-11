import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/core/firebase/firebase_providers.dart';
import 'package:zyncro/core/notifications/firestore_push_token_repository.dart';
import 'package:zyncro/core/notifications/notification_preferences.dart';
import 'package:zyncro/core/notifications/push_notification_service.dart';
import 'package:zyncro/core/notifications/push_token_repository.dart';

/// Dernier message reçu au premier plan (affiché par le bandeau in-app).
class ForegroundMessageNotifier extends Notifier<RemoteMessage?> {
  @override
  RemoteMessage? build() => null;
  void set(RemoteMessage? message) => state = message;
}

final foregroundMessageProvider =
    NotifierProvider<ForegroundMessageNotifier, RemoteMessage?>(
      ForegroundMessageNotifier.new,
    );

final pushTokenRepositoryProvider = Provider<PushTokenRepository>(
  (ref) => FirestorePushTokenRepository(ref.watch(firestoreProvider)),
);

final notificationPreferencesProvider = Provider<NotificationPreferences>(
  (_) => NotificationPreferences(),
);

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(
    messaging: ref.watch(firebaseMessagingProvider),
    tokens: ref.watch(pushTokenRepositoryProvider),
    auth: ref.watch(firebaseAuthProvider),
    onForegroundMessage: (message) =>
        ref.read(foregroundMessageProvider.notifier).set(message),
  ),
);
