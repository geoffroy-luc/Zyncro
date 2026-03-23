import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../shared/models/event.dart';

class ReminderService {
  static const _prefKey = 'event_reminders_v1';
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  static int _notifId(String eventId) => eventId.hashCode & 0x7fffffff;

  static Future<Map<String, int>> _loadMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  static Future<void> _saveMap(Map<String, int> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(map));
  }

  /// Returns the saved reminder offset in minutes, or null if none.
  static Future<int?> getReminderMinutes(String eventId) async {
    final map = await _loadMap();
    return map[eventId];
  }

  /// Schedules (or cancels) the local notification reminder for [event].
  /// Pass [reminderMinutes] = null to remove the reminder.
  static Future<void> scheduleReminder(Event event, int? reminderMinutes) async {
    await cancelReminder(event.id);

    if (reminderMinutes == null) {
      final map = await _loadMap();
      map.remove(event.id);
      await _saveMap(map);
      return;
    }

    final map = await _loadMap();
    map[event.id] = reminderMinutes;
    await _saveMap(map);

    final scheduledDate =
        event.startDate.subtract(Duration(minutes: reminderMinutes));
    if (!scheduledDate.isAfter(DateTime.now())) return;

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const android = AndroidNotificationDetails(
      'event_reminders',
      'Rappels d\'événements',
      channelDescription: 'Notifications de rappel pour les événements du calendrier',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: android,
      iOS: DarwinNotificationDetails(),
    );

    final body = reminderMinutes == 0
        ? 'L\'événement commence maintenant'
        : _beforeLabel(reminderMinutes);

    await _plugin.zonedSchedule(
      _notifId(event.id),
      event.title,
      body,
      tzDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: event.id,
    );
  }

  static Future<void> cancelReminder(String eventId) async {
    await _plugin.cancel(_notifId(eventId));
  }

  static String _beforeLabel(int minutes) {
    if (minutes < 60) return 'Dans $minutes min';
    if (minutes == 60) return 'Dans 1 heure';
    if (minutes < 1440) return 'Dans ${minutes ~/ 60} heures';
    if (minutes == 1440) return 'Dans 1 jour';
    return 'Dans ${minutes ~/ 1440} jours';
  }
}
