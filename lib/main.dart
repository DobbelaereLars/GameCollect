import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'dart:async';

import 'app.dart';
import 'core/database/database_helper.dart';
import 'core/notifications/notification_service.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/sync/auth_service.dart';
import 'core/sync/connectivity_service.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/app_theme_controller.dart';
import 'firebase_options.dart';

/// Ingangspunt van de app. Initialiseert alle services voor de UI opstart.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Laad de opgeslagen thema-voorkeur (auto/licht/donker) zodra mogelijk.
  await AppThemeController.instance.initialize();

  // Ga door ook als .env ontbreekt; de Ontdekken-pagina toont een duidelijke melding.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  // Migreer de RAWG API-sleutel naar de veilige opslag (Keychain / EncryptedSharedPreferences).
  await SecureStorageService.initialize();

  await NotificationService.instance.initialize();

  // Plan een dagelijkse herinnering als notificaties zijn ingeschakeld.
  final notificationsEnabled = await DatabaseHelper.instance
      .getNotificationsEnabled();
  if (notificationsEnabled) {
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.scheduleAll();
  }

  // Initialiseer Firebase. De app blijft werken in lokaal-only modus als dit
  // mislukt (bijv. voor `flutterfire configure` is uitgevoerd).
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
  // Voer initiële sync uit op de achtergrond; veilige no-op als niet ingelogd of offline.
  unawaited(SyncService.instance.syncNow());

  runApp(const GameCollectApp());
}
