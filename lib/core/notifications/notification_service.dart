import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../database/database_helper.dart';
import '../../features/collection/domain/collection_item.dart';

/// Service voor lokale pushmeldingen: dagelijkse herinneringen en toestemming.
class NotificationService {
  NotificationService._();

  /// Singleton-instantie, globaal toegankelijk.
  static final NotificationService instance = NotificationService._();

  // Onderliggende notificatieplugin.
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Vaste ID voor de dagelijkse herinnering.
  static const int _dailyReminderId = 1;

  // ── Initialisatie ──────────────────────────────────────────────────────────

  /// Initialiseert de notificatieplugin voor iOS en Android.
  Future<void> initialize() async {
    tz.initializeTimeZones();
    // Stel de lokale tijdzone in zodat geplande notificaties op het juiste lokale uur worden afgeleverd.
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const macOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macOSSettings,
    );

    await _plugin.initialize(initSettings);
  }

  // ── Machtigingen ─────────────────────────────────────────────────────────────

  /// Geeft terug of de gebruiker systeemnotificaties heeft toegestaan.
  Future<bool> arePermissionsGranted() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final perms = await ios.checkPermissions();
      return perms?.isEnabled ?? false;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }

    return false;
  }

  /// Vraagt de gebruiker om toestemming voor meldingen (iOS en Android 13+).
  Future<bool> requestPermissions() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    return false;
  }

  // ── Dagelijkse herinnering ──────────────────────────────────────────────────

  /// Plant een dagelijkse notificatie om 19:00 met een willekeurige game
  /// uit de opgegeven lijst. Vervangt een eventueel bestaande herinnering.
  Future<void> scheduleDailyReminder(List<CollectionItem> items) async {
    final enabled = await DatabaseHelper.instance.getNotificationsEnabled();
    if (!enabled) return;

    // Kies een game die bezig is, niet voltooid en de laatste 5 dagen gespeeld.
    final cutoff = DateTime.now().subtract(const Duration(days: 5));
    final candidates = items.where((i) {
      if (i.isManuallyCompleted || i.progressRatio >= 1.0) return false;
      return i.playtimeEntries.any((e) {
        final d = DateTime.tryParse(e.date);
        return d != null && d.isAfter(cutoff);
      });
    }).toList();

    if (candidates.isEmpty) {
      await cancelDailyReminder();
      return;
    }

    candidates.shuffle();
    final game = candidates.first;

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder',
      'Dagelijkse herinnering',
      channelDescription: 'Herinnering om een game verder te spelen',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      19,
      0,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Tijd om te gamen! 🎮',
      'Ga verder met ${game.title}',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_dailyReminderId);
  }

  // ── Alles annuleren ──────────────────────────────────────────────────────────

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    if (kDebugMode) {
      debugPrint('[NotificationService] Alle notificaties geannuleerd.');
    }
  }

  // ── Alles inplannen (opnieuw inschakelen) ───────────────────────────────────

  Future<void> scheduleAll() async {
    final items = await DatabaseHelper.instance.getCollectionItems();
    await scheduleDailyReminder(items);
  }
}
