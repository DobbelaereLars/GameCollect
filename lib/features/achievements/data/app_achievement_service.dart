import 'package:flutter/foundation.dart';

import '../../../core/database/database_helper.dart';
import '../../collection/domain/collection_item.dart';
import '../domain/app_achievement.dart';

class AppAchievementService extends ChangeNotifier {
  static final AppAchievementService instance = AppAchievementService._init();
  AppAchievementService._init();

  static const String _shareCounterKey = 'share_count';

  /// Fires whenever new achievements are unlocked. The shell listens to this
  /// and shows a global snackbar. The value is cleared after being consumed.
  static final newlyUnlockedNotifier = ValueNotifier<List<AppAchievement>>([]);

  // ── Stats computation ────────────────────────────────────────────────────

  Future<Map<AchievementType, int>> _computeStats(
    List<CollectionItem> items,
  ) async {
    // Total unique games
    final uniqueApiIds = items.map((e) => e.apiId).toSet();
    final totalGames = uniqueApiIds.length;

    // Physical games: unique apiIds where any entry is 'Fysiek' or 'Allebei'
    final physicalApiIds = items
        .where((e) => e.format == 'Fysiek' || e.format == 'Allebei')
        .map((e) => e.apiId)
        .toSet();
    final physicalGames = physicalApiIds.length;

    // Completed games: unique apiIds where any entry is completed
    final completedApiIds = <int>{};
    for (final id in uniqueApiIds) {
      final group = items.where((e) => e.apiId == id).toList();
      final isCompleted = group.any(
        (e) => e.isManuallyCompleted || e.progressRatio >= 1.0,
      );
      if (isCompleted) completedApiIds.add(id);
    }
    final completedGames = completedApiIds.length;

    // Total playtime in minutes
    final totalPlaytimeMinutes = items.fold<int>(
      0,
      (sum, e) => sum + e.totalPlaytimeMinutes,
    );

    // Distinct platforms
    final platforms = <String>{};
    for (final item in items) {
      for (final p in item.selectedPlatforms) {
        platforms.add(p.replaceAll(RegExp(r'\s*\(.*\)$'), ''));
      }
    }
    final platformCount = platforms.length;

    // Notes written (at least 1 game with non-empty notes)
    final notesWritten = items.any((e) => e.notes.trim().isNotEmpty) ? 1 : 0;

    // Online achievements loaded (at least 1 game with achievementStates)
    final onlineLoaded = items.any((e) => e.achievementStates.isNotEmpty)
        ? 1
        : 0;

    // Share count (from event counter)
    final shareCount = await DatabaseHelper.instance.getEventCounter(
      _shareCounterKey,
    );

    return {
      AchievementType.totalGames: totalGames,
      AchievementType.physicalGames: physicalGames,
      AchievementType.completedGames: completedGames,
      AchievementType.playtimeMinutes: totalPlaytimeMinutes,
      AchievementType.platformCount: platformCount,
      AchievementType.notesWritten: notesWritten,
      AchievementType.shareCount: shareCount,
      AchievementType.onlineAchievementsLoaded: onlineLoaded,
    };
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Computes progress for every achievement and returns the full list.
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

  /// Evaluates all achievements against current stats, unlocks newly eligible
  /// ones, and returns a list of newly unlocked [AppAchievement]s.
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

  /// Marks all currently unseen unlocked achievements as seen and returns them.
  Future<List<AppAchievementProgress>> popNewlyUnlocked(
    List<AppAchievementProgress> progressList,
  ) async {
    final unseen = progressList.where((p) => p.isNew).toList();
    for (final p in unseen) {
      await DatabaseHelper.instance.markAppAchievementSeen(p.achievement.id);
    }
    return unseen;
  }

  /// Records a share event (used by CollectionItemDetailPage after sharing).
  Future<void> recordShareEvent(List<CollectionItem> items) async {
    await DatabaseHelper.instance.incrementEventCounter(_shareCounterKey);
    await checkAndUnlock(items);
  }
}
