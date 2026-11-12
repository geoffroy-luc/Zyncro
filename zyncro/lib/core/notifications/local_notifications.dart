import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Canal Android « haute importance » (bannières heads-up FCM). Même
/// identifiant que côté Cloud Functions (functions/src/notifications/fcm.ts).
const highImportanceChannelId = 'zyncro_high_importance';

/// Handler des messages reçus en arrière-plan — doit être une fonction de
/// premier niveau. Les notifications sont affichées par le système.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

abstract final class LocalNotifications {
  /// Crée le canal haute importance. À appeler une fois avant runApp().
  static Future<void> createNotificationChannel() async {
    if (!Platform.isAndroid) return;
    const channel = AndroidNotificationChannel(
      highImportanceChannelId,
      'Notifications Zyncro',
      description: 'Notifications de messages et d\'activité',
      importance: Importance.high,
    );
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// À appeler une fois après Firebase.initializeApp(), avant runApp().
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Retire toutes les notifications de l'app du centre de notifications.
  static Future<void> dismissAll() async {
    if (Platform.isAndroid) {
      await FlutterLocalNotificationsPlugin().cancelAll();
    } else if (Platform.isIOS) {
      const channel = MethodChannel('com.zyncro.app/notifications');
      await channel.invokeMethod<void>('dismissAllNotifications');
    }
  }
}
