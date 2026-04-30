import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../database/database_helper.dart';
import '../../features/collection/domain/collection_item.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyReminderId = 1;

  // ── Initialisation ──────────────────────────────────────────────────────────

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
  }

  // ── Permissions ─────────────────────────────────────────────────────────────

  /// Returns whether the user has granted notification permission at system level.
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

  // ── Daily reminder ──────────────────────────────────────────────────────────

  /// Schedules a daily notification at 19:00 with a random game from the
  /// provided list. Replaces any existing daily reminder.
  Future<void> scheduleDailyReminder(List<CollectionItem> items) async {
    final enabled = await DatabaseHelper.instance.getNotificationsEnabled();
    if (!enabled) return;

    // Pick a game that is in progress, not completed, and played in the last 5 days.
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

  // ── Cancel all ──────────────────────────────────────────────────────────────

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    if (kDebugMode)
      debugPrint('[NotificationService] All notifications cancelled.');
  }

  // ── Schedule all (re-enable) ─────────────────────────────────────────────────

  Future<void> scheduleAll() async {
    final items = await DatabaseHelper.instance.getCollectionItems();
    await scheduleDailyReminder(items);
  }
}
