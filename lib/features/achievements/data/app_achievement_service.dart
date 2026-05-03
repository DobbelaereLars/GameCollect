import 'package:flutter/foundation.dart';

import '../../../core/database/database_helper.dart';
import '../../collection/domain/collection_item.dart';
import '../domain/app_achievement.dart';

class AppAchievementService extends ChangeNotifier {
  static final AppAchievementService instance = AppAchievementService._init();
  AppAchievementService._init();

  static const String _shareCounterKey = 'share_count';

  /// Wordt gevuurd zodra nieuwe achievements worden ontgrendeld. De shell luistert
  /// hierop en toont een globale snackbar. De waarde wordt gewist na verwerking.
  static final newlyUnlockedNotifier = ValueNotifier<List<AppAchievement>>([]);

  // ── Statistiekenberekening ────────────────────────────────────────────────────

  Future<Map<AchievementType, int>> _computeStats(
    List<CollectionItem> items,
  ) async {
    // Uniek totaalaantal games
    final uniqueApiIds = items.map((e) => e.apiId).toSet();
    final totalGames = uniqueApiIds.length;

    // Fysieke games: unieke apiIds waarbij een item 'Fysiek' of 'Fysiek & Digitaal' is
    final physicalApiIds = items
        .where((e) => e.format == 'Fysiek' || e.format == 'Fysiek & Digitaal')
        .map((e) => e.apiId)
        .toSet();
    final physicalGames = physicalApiIds.length;

    // Voltooide games: unieke apiIds waarbij een item voltooid is
    final completedApiIds = <int>{};
    for (final id in uniqueApiIds) {
      final group = items.where((e) => e.apiId == id).toList();
      final isCompleted = group.any(
        (e) => e.isManuallyCompleted || e.progressRatio >= 1.0,
      );
      if (isCompleted) completedApiIds.add(id);
    }
    final completedGames = completedApiIds.length;

    // Totale speelduur in minuten
    final totalPlaytimeMinutes = items.fold<int>(
      0,
      (sum, e) => sum + e.totalPlaytimeMinutes,
    );

    // Unieke platformen
    final platforms = <String>{};
    for (final item in items) {
      for (final p in item.selectedPlatforms) {
        platforms.add(p.replaceAll(RegExp(r'\s*\(.*\)$'), ''));
      }
    }
    final platformCount = platforms.length;

    // Notities geschreven: aantal unieke games met niet-lege notities
    final notesWrittenApiIds = items
        .where((e) => e.notes.trim().isNotEmpty)
        .map((e) => e.apiId)
        .toSet();
    final notesWritten = notesWrittenApiIds.length;

    // Online achievements geladen (games met achievementStates)
    final onlineLoaded = items
        .where((e) => e.achievementStates.isNotEmpty)
        .map((e) => e.apiId)
        .toSet()
        .length;

    // Digitale games: unieke apiIds waarbij een item 'Digitaal' of 'Fysiek & Digitaal' is
    final digitalApiIds = items
        .where((e) => e.format == 'Digitaal' || e.format == 'Fysiek & Digitaal')
        .map((e) => e.apiId)
        .toSet();
    final digitalGames = digitalApiIds.length;

    // Tags gebruikt: unieke apiIds waarbij een item minstens één actieve tag heeft
    final taggedApiIds = items
        .where((e) => e.activeTags.isNotEmpty)
        .map((e) => e.apiId)
        .toSet();
    final tagsUsed = taggedApiIds.length;

    // Deelcount (via gebeurtenisteller)
    final shareCount = await DatabaseHelper.instance.getEventCounter(
      _shareCounterKey,
    );

    return {
      AchievementType.totalGames: totalGames,
      AchievementType.physicalGames: physicalGames,
      AchievementType.digitalGames: digitalGames,
      AchievementType.completedGames: completedGames,
      AchievementType.playtimeMinutes: totalPlaytimeMinutes,
      AchievementType.platformCount: platformCount,
      AchievementType.notesWritten: notesWritten,
      AchievementType.shareCount: shareCount,
      AchievementType.onlineAchievementsLoaded: onlineLoaded,
      AchievementType.tagsUsed: tagsUsed,
    };
  }

  // ── Publieke API ──────────────────────────────────────────────────────────────

  /// Berekent voortgang voor elk achievement en geeft de volledige lijst terug.
  Future<List<AppAchievementProgress>> getProgress(
    List<CollectionItem> items,
  ) async {
    final stats = await _computeStats(items);
    final unlocked = await DatabaseHelper.instance.getAppAchievements();

    return AppAchievement.all
        .map((achievement) {
          final current = stats[achievement.type] ?? 0;
          final row = unlocked[achievement.id];
          final isUnlocked = row != null;
          final unlockedAt = row != null && row['unlockedAt'] != null
              ? DateTime.tryParse(row['unlockedAt']!)
              : null;
          final isNew = isUnlocked && row['seenAt'] == null;
          return AppAchievementProgress(
            achievement: achievement,
            currentCount: current,
            isUnlocked: isUnlocked,
            unlockedAt: unlockedAt,
            isNew: isNew,
          );
        })
        .toList(growable: false);
  }

  /// Evalueert alle achievements aan de hand van de huidige statistieken,
  /// ontgrendelt nieuwe en geeft de lijst van nieuw ontgrendelde terug.
  Future<List<AppAchievement>> checkAndUnlock(
    List<CollectionItem> items,
  ) async {
    final stats = await _computeStats(items);
    final alreadyUnlocked = await DatabaseHelper.instance.getAppAchievements();
    final newlyUnlocked = <AppAchievement>[];

    for (final achievement in AppAchievement.all) {
      if (alreadyUnlocked.containsKey(achievement.id)) continue;
      final current = stats[achievement.type] ?? 0;
      if (current >= achievement.targetCount) {
        await DatabaseHelper.instance.unlockAppAchievement(achievement.id);
        newlyUnlocked.add(achievement);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      AppAchievementService.newlyUnlockedNotifier.value = List.unmodifiable(
        newlyUnlocked,
      );
      notifyListeners();
    }

    return newlyUnlocked;
  }

  /// Markeert alle ongeziene ontgrendelde achievements als gezien en geeft ze terug.
  Future<List<AppAchievementProgress>> popNewlyUnlocked(
    List<AppAchievementProgress> progressList,
  ) async {
    final unseen = progressList.where((p) => p.isNew).toList();
    for (final p in unseen) {
      await DatabaseHelper.instance.markAppAchievementSeen(p.achievement.id);
    }
    return unseen;
  }

  /// Registreert een deelevenement (aangeroepen door CollectionItemDetailPage na het delen).
  Future<void> recordShareEvent(List<CollectionItem> items) async {
    await DatabaseHelper.instance.incrementEventCounter(_shareCounterKey);
    await checkAndUnlock(items);
  }
}
