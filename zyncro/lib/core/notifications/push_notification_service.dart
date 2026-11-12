import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:zyncro/core/logging/app_logger.dart';
import 'package:zyncro/core/notifications/push_token_repository.dart';

/// Ouverture d'une notification : groupe visé et onglet (`screen`).
/// Fourni par la couche app (sélection du groupe + navigation) : `core` ne
/// dépend ainsi ni du router ni des features.
typedef NotificationTapHandler =
    Future<void> Function(String groupId, String? screen);

/// Notifications push (FCM) : permission, token, messages au premier plan,
/// ouverture depuis une notification.
class PushNotificationService {
  PushNotificationService({
    required FirebaseMessaging messaging,
    required PushTokenRepository tokens,
    required FirebaseAuth auth,
    required void Function(RemoteMessage message) onForegroundMessage,
  }) : _messaging = messaging,
       _tokens = tokens,
       _auth = auth,
       _onForegroundMessage = onForegroundMessage;

  final FirebaseMessaging _messaging;
  final PushTokenRepository _tokens;
  final FirebaseAuth _auth;
  final void Function(RemoteMessage message) _onForegroundMessage;

  /// Branché par l'app au démarrage.
  NotificationTapHandler? onTap;

  // Abonnements annulés au logout pour éviter les listeners fantômes.
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  /// Demande de permission en cours : une seule à la fois. Se déconnecter
  /// puis se reconnecter sans avoir répondu au dialogue relançait une
  /// demande, et firebase_messaging levait « A request for permissions is
  /// already running » (exception non gérée).
  Future<NotificationSettings>? _pendingPermission;

  /// À appeler quand un utilisateur est authentifié.
  Future<void> initialize(String userId) async {
    // Annuler les anciens listeners avant d'en créer de nouveaux.
    // BUG G16 corrigé : _openedAppSub aussi (sinon un tap sur notification
    // était traité deux fois après un second initialize).
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedAppSub?.cancel();

    // Permission (iOS & Android 13+), partagée si une demande est en cours.
    final settings = await (_pendingPermission ??= _messaging
        .requestPermission()
        .whenComplete(() => _pendingPermission = null));
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    // Ne jamais journaliser le token FCM (visible dans logcat en release).
    AppLogger.info('FCM', 'token ${token == null ? 'absent' : 'obtenu'}');
    if (token != null) await _saveToken(userId, token);

    _tokenRefreshSub = _messaging.onTokenRefresh.listen(
      (t) => _saveToken(userId, t),
    );

    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Démarrage à froid : app lancée depuis une notification.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_handleNotificationTap(initialMessage));
      });
    }

    // Arrière-plan → premier plan : tap sur une notification.
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(_handleNotificationTap(message));
    });
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    AppLogger.info('Notif', 'tap — data: ${message.data}');
    final groupId = message.data['groupId'] as String?;
    if (groupId == null) return;
    final screen = message.data['screen'] as String?;
    AppLogger.info('Notif', 'groupId=$groupId  screen=$screen');
    await onTap?.call(groupId, screen);
  }

  Future<void> _saveToken(String userId, String token) async {
    try {
      await _tokens.saveToken(userId, token);
      AppLogger.info('FCM', 'token saved for $userId');
    } on FirebaseException catch (e) {
      AppLogger.warning('FCM', 'token save FAILED: ${e.code} — ${e.message}');
    }
  }

  /// Active / désactive les notifications de l'utilisateur sur cet appareil
  /// (interrupteur du profil).
  Future<void> setEnabledForUser(String uid, {required bool enabled}) async {
    if (enabled) {
      final token = await _messaging.getToken();
      if (token != null) await _tokens.saveTokenOnly(uid, token);
    } else {
      try {
        await _tokens.clearToken(uid);
      } on Object catch (e) {
        AppLogger.warning('FCM', 'clear token ignored', e);
      }
      await _messaging.deleteToken();
    }
  }

  /// Retire le token à la déconnexion (l'utilisateur ne reçoit plus rien).
  Future<void> removeToken() async {
    // Annuler les listeners immédiatement pour éviter tout appel post-logout.
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedAppSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub = null;
    _openedAppSub = null;

    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _tokens.clearToken(user.uid);
    } on FirebaseException {
      // Utilisateur déjà déconnecté ou règles refusant l'accès : on ignore.
    }
    await _messaging.deleteToken();
  }
}
