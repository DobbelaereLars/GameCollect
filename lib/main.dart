import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/database/database_helper.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Keep running even if .env is missing; the Discover page shows a clear message.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await NotificationService.instance.initialize();

  // Schedule daily reminder if notifications are enabled.
  final notificationsEnabled =
      await DatabaseHelper.instance.getNotificationsEnabled();
  if (notificationsEnabled) {
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.scheduleAll();
  }

  runApp(const GameCollectApp());
}
