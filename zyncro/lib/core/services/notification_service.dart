import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized at this point.
  // Background notifications are shown automatically by the OS.
}

/// Holds the latest foreground message so the UI can react.
class _ForegroundMessageNotifier extends Notifier<RemoteMessage?> {
  @override
  RemoteMessage? build() => null;
  void set(RemoteMessage? message) => state = message;
}

final foregroundMessageProvider =
    NotifierProvider<_ForegroundMessageNotifier, RemoteMessage?>(
      _ForegroundMessageNotifier.new,
    );

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;

  /// Call once after Firebase.initializeApp() — before runApp().
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Call when a user is authenticated.
  static Future<void> initialize(String userId, WidgetRef ref) async {
    // Request permission (iOS & Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Save initial token
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(userId, token);

    // Refresh token
    _messaging.onTokenRefresh.listen((t) => _saveToken(userId, t));

    // Foreground messages → update provider so the UI can show a banner
    FirebaseMessaging.onMessage.listen((message) {
      ref.read(foregroundMessageProvider.notifier).set(message);
    });

    // Opened from notification while app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // Navigate based on message data if needed in the future
    });
  }

  static Future<void> _saveToken(String userId, String token) async {
    await _db.collection('users').doc(userId).set(
      {'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Remove token on sign-out so the user stops receiving notifications.
  static Future<void> removeToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({'fcmToken': null});
    await _messaging.deleteToken();
  }
}

/// Widget that shows a temporary in-app banner when a foreground message arrives.
class NotificationBanner extends ConsumerWidget {
  final Widget child;
  const NotificationBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<RemoteMessage?>(foregroundMessageProvider, (_, message) {
      if (message == null) return;
      final notification = message.notification;
      if (notification == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notification.title != null)
                Text(
                  notification.title!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              if (notification.body != null) Text(notification.body!),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    });

    return child;
  }
}
