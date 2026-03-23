import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_lib;
import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'core/services/reminder_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    initializeDateFormatting('fr_FR', null),
  ]);
  await FirebaseAppCheck.instance.activate(
    providerAndroid: AndroidDebugProvider(),
  );
  tz.initializeTimeZones();
  final tzInfo = await FlutterTimezone.getLocalTimezone();
  tz_lib.setLocalLocation(tz_lib.getLocation(tzInfo.identifier));
  await ReminderService.initialize();
  NotificationService.registerBackgroundHandler();
  runApp(const ProviderScope(child: ZyncroApp()));
}
