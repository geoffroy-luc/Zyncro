import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/router.dart';
import '../../features/groups/presentation/providers/groups_provider.dart';

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

  // Subscriptions à annuler lors du logout pour éviter les listeners fantômes
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _foregroundSub;
  static StreamSubscription<RemoteMessage>? _openedAppSub;

  /// Call once after Firebase.initializeApp() — before runApp().
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Call when a user is authenticated.
  static Future<void> initialize(String userId, WidgetRef ref) async {
    // Annuler les anciens listeners avant d'en créer de nouveaux
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();

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

    // Refresh token — stocké pour pouvoir l'annuler au logout
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(
      (t) => _saveToken(userId, t),
    );

    // Foreground messages — stocké pour pouvoir l'annuler au logout
    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      ref.read(foregroundMessageProvider.notifier).set(message);
    });

    // Cold start : app lancée depuis une notif (app était terminée)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationTap(initialMessage, ref);
      });
    }

    // Background → foreground : tap sur une notif
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message, ref);
    });
  }

  static Future<void> _handleNotificationTap(
    RemoteMessage message,
    WidgetRef ref,
  ) async {
    debugPrint('[Notif] tap — data: ${message.data}');

    final groupId = message.data['groupId'] as String?;
    if (groupId == null) return;

    final screen = message.data['screen'] as String?;
    final route = switch (screen) {
      'chat' => '/chat',
      'expenses' => '/expenses',
      'notes' => '/notes',
      'calendar' => '/calendar',
      _ => '/home',
    };

    debugPrint('[Notif] groupId=$groupId  screen=$screen  → route=$route');

    // Sélectionner le bon groupe
    await ref.read(selectedGroupIdProvider.notifier).select(groupId);

    // Double post-frame : le 1er frame laisse GoRouter traiter le refresh
    // déclenché par selectedGroupIdProvider, le 2e effectue la navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('[Notif] navigating → $route');
        ref.read(routerProvider).go(route);
      });
    });
  }

  static Future<void> _saveToken(String userId, String token) async {
    try {
      await _db.collection('users').doc(userId).set(
        {'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } on FirebaseException {
      // Règles Firestore non configurées pour la collection users — on ignore.
    }
  }

  /// Remove token on sign-out so the user stops receiving notifications.
  static Future<void> removeToken() async {
    // Annuler les listeners immédiatement pour éviter tout appel post-logout
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedAppSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub = null;
    _openedAppSub = null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).update({'fcmToken': null});
    } on FirebaseException {
      // Règles non configurées ou utilisateur déjà déconnecté — on ignore.
    }
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

      // Ne pas afficher le bandeau si on est déjà sur l'écran correspondant
      final screen = message.data['screen'] as String?;
      if (screen != null) {
        final currentPath = ref.read(routerProvider).routeInformationProvider.value.uri.path;
        if (currentPath == '/$screen') return;
      }

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
