import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  static const _channelId = 'zyncro_high_importance';
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;

  // Subscriptions à annuler lors du logout pour éviter les listeners fantômes
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _foregroundSub;
  static StreamSubscription<RemoteMessage>? _openedAppSub;

  /// Creates the high-importance Android notification channel so FCM shows heads-up banners.
  /// Call once before runApp(), after Firebase.initializeApp().
  static Future<void> createNotificationChannel() async {
    if (!Platform.isAndroid) return;
    const channel = AndroidNotificationChannel(
      _channelId,
      'Notifications Zyncro',
      description: 'Notifications de messages et d\'activité',
      importance: Importance.high,
    );
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

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
    debugPrint('[FCM] token=$token');
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
      debugPrint('[FCM] token saved for $userId');
    } on FirebaseException catch (e) {
      debugPrint('[FCM] token save FAILED: ${e.code} — ${e.message}');
    }
  }

  /// Dismisses all app notifications from the OS notification tray.
  static Future<void> dismissAllNotifications() async {
    if (Platform.isAndroid) {
      await FlutterLocalNotificationsPlugin().cancelAll();
    } else if (Platform.isIOS) {
      const channel = MethodChannel('com.zyncro.app/notifications');
      await channel.invokeMethod<void>('dismissAllNotifications');
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
/// Multiple messages arriving within 600 ms are grouped into one snackbar.
class NotificationBanner extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationBanner({super.key, required this.child});

  @override
  ConsumerState<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends ConsumerState<NotificationBanner> {
  final List<RemoteMessage> _pending = [];
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _enqueue(RemoteMessage message) {
    _pending.add(message);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 600), _flush);
  }

  void _flush() {
    if (!mounted || _pending.isEmpty) return;

    final messages = List<RemoteMessage>.from(_pending);
    _pending.clear();

    // Filtrer les messages dont on est déjà sur l'écran
    final currentPath =
        ref.read(routerProvider).routeInformationProvider.value.uri.path;
    final visible = messages.where((m) {
      final screen = m.data['screen'] as String?;
      return screen == null || currentPath != '/$screen';
    }).toList();

    if (visible.isEmpty) return;

    final SnackBar snackBar;
    if (visible.length == 1) {
      final notif = visible.first.notification;
      if (notif == null) return;
      snackBar = SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notif.title != null)
              Text(notif.title!,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            if (notif.body != null) Text(notif.body!),
          ],
        ),
        duration: const Duration(seconds: 4),
      );
    } else {
      snackBar = SnackBar(
        content: Text('${visible.length} nouvelles notifications'),
        duration: const Duration(seconds: 4),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RemoteMessage?>(foregroundMessageProvider, (_, message) {
      if (message == null) return;
      if (message.notification == null) return;
      _enqueue(message);
    });

    return widget.child;
  }
}
