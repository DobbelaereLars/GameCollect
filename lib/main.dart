import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'dart:async';

import 'app.dart';
import 'core/database/database_helper.dart';
import 'core/notifications/notification_service.dart';
import 'core/sync/auth_service.dart';
import 'core/sync/connectivity_service.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/app_theme_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Laad de opgeslagen thema-voorkeur (auto/licht/donker) zodra mogelijk.
  await AppThemeController.instance.initialize();

  // Keep running even if .env is missing; the Discover page shows a clear message.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await NotificationService.instance.initialize();

  // Schedule daily reminder if notifications are enabled.
  final notificationsEnabled = await DatabaseHelper.instance
      .getNotificationsEnabled();
  if (notificationsEnabled) {
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.scheduleAll();
  }

  // Try to bring up Firebase. The app keeps working in local-only mode if this
  // fails (e.g. before `flutterfire configure` has been run).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase niet geïnitialiseerd (lokaal-only modus): $e');
  }

  await AuthService.instance.initialize();
  await ConnectivityService.instance.initialize();
  await SyncService.instance.wire();
  // Fire-and-forget initial sync; safe no-op when not signed in or offline.
  unawaited(SyncService.instance.syncNow());

  runApp(const GameCollectApp());
}
