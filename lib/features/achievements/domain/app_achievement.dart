import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum AchievementType {
  totalGames,
  physicalGames,
  digitalGames,
  completedGames,
  playtimeMinutes,
  platformCount,
  notesWritten,
  shareCount,
  onlineAchievementsLoaded,
  tagsUsed,
}

class AppAchievement {
  const AppAchievement({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.type,
    required this.targetCount,
  });

  final String id;
  final IconData icon;
  final String title;
  final String description;
  final AchievementType type;
  final int targetCount;

  static const List<AppAchievement> all = [
    // Collection size
    AppAchievement(
      id: 'first_game',
      icon: LucideIcons.gamepad2,
      title: 'Eerste Stap',
      description: 'Voeg je eerste game toe aan de collectie',
      type: AchievementType.totalGames,
      targetCount: 1,
    ),
    AppAchievement(
      id: 'collector_10',
      icon: LucideIcons.library,
      title: 'Beginner Verzamelaar',
      description: '10 unieke games in je collectie',
      type: AchievementType.totalGames,
      targetCount: 10,
    ),
    AppAchievement(
      id: 'collector_25',
      icon: LucideIcons.library,
      title: 'Groeier',
      description: '25 unieke games in je collectie',
      type: AchievementType.totalGames,
      targetCount: 25,
    ),
    AppAchievement(
      id: 'collector_50',
      icon: LucideIcons.library,
      title: 'Serieuze Verzamelaar',
      description: '50 unieke games in je collectie',
      type: AchievementType.totalGames,
      targetCount: 50,
    ),
    AppAchievement(
      id: 'collector_100',
      icon: LucideIcons.library,
      title: 'Mega Verzamelaar',
      description: '100 unieke games in je collectie',
      type: AchievementType.totalGames,
      targetCount: 100,
    ),
    AppAchievement(
      id: 'collector_200',
      icon: LucideIcons.library,
      title: 'Legendarische Verzamelaar',
      description: '200 unieke games in je collectie',
      type: AchievementType.totalGames,
      targetCount: 200,
    ),
    // Physical games
    AppAchievement(
      id: 'physical_10',
      icon: LucideIcons.disc3,
      title: 'Fysieke Collectie',
      description: '10 verschillende fysieke games toegevoegd',
      type: AchievementType.physicalGames,
      targetCount: 10,
    ),
    AppAchievement(
      id: 'physical_25',
      icon: LucideIcons.disc3,
      title: 'Fysieke Fan',
      description: '25 verschillende fysieke games toegevoegd',
      type: AchievementType.physicalGames,
      targetCount: 25,
    ),
    AppAchievement(
      id: 'physical_50',
      icon: LucideIcons.disc3,
      title: 'Discopolitist',
      description: '50 verschillende fysieke games toegevoegd',
      type: AchievementType.physicalGames,
      targetCount: 50,
    ),
    AppAchievement(
      id: 'physical_100',
      icon: LucideIcons.disc3,
      title: 'Groot Fysiek Archief',
      description: '100 verschillende fysieke games toegevoegd',
      type: AchievementType.physicalGames,
      targetCount: 100,
    ),
    // Digital games
    AppAchievement(
      id: 'digital_1',
      icon: LucideIcons.download,
      title: 'Digitaal Pionier',
      description: 'Je eerste digitale game toegevoegd',
      type: AchievementType.digitalGames,
      targetCount: 1,
    ),
    AppAchievement(
      id: 'digital_10',
      icon: LucideIcons.download,
      title: 'Digitale Collectie',
      description: '10 verschillende digitale games in je collectie',
      type: AchievementType.digitalGames,
      targetCount: 10,
    ),
    // Completion
    AppAchievement(
      id: 'completed_1',
      icon: LucideIcons.star,
      title: 'Platina Jager',
      description: 'Voltooi je eerste game volledig',
      type: AchievementType.completedGames,
      targetCount: 1,
    ),
    AppAchievement(
      id: 'completed_3',
      icon: LucideIcons.star,
      title: 'Doorzetter',
      description: '3 verschillende games volledig gecompleteerd',
      type: AchievementType.completedGames,
      targetCount: 3,
    ),
    AppAchievement(
      id: 'completed_10',
      icon: LucideIcons.trophy,
      title: 'Completionist',
      description: '10 verschillende games volledig gecompleteerd',
      type: AchievementType.completedGames,
      targetCount: 10,
    ),
    AppAchievement(
      id: 'completed_25',
      icon: LucideIcons.trophy,
      title: 'Completionist Pro',
      description: '25 verschillende games volledig gecompleteerd',
      type: AchievementType.completedGames,
      targetCount: 25,
    ),
    AppAchievement(
      id: 'completed_50',
      icon: LucideIcons.trophy,
      title: 'Completionist Legende',
      description: '50 verschillende games volledig gecompleteerd',
      type: AchievementType.completedGames,
      targetCount: 50,
    ),
    // Playtime
    AppAchievement(
      id: 'playtime_1h',
      icon: LucideIcons.clock,
      title: 'Eerste Sessie',
      description: '1 uur speelduur gelogd',
      type: AchievementType.playtimeMinutes,
      targetCount: 60,
    ),
    AppAchievement(
      id: 'playtime_10h',
      icon: LucideIcons.clock,
      title: 'Casual Gamer',
      description: '10 uur speelduur gelogd',
      type: AchievementType.playtimeMinutes,
      targetCount: 600,
    ),
    AppAchievement(
      id: 'playtime_50h',
      icon: LucideIcons.clock,
      title: 'Verslaafde Gamer',
      description: '50 uur speelduur gelogd',
      type: AchievementType.playtimeMinutes,
      targetCount: 3000,
    ),
    AppAchievement(
      id: 'playtime_100h',
      icon: LucideIcons.clock,
      title: 'Hardcore Gamer',
      description: '100 uur speelduur gelogd',
      type: AchievementType.playtimeMinutes,
      targetCount: 6000,
    ),
    AppAchievement(
      id: 'playtime_500h',
      icon: LucideIcons.clock,
      title: 'Tijdloze Gamer',
      description: '500 uur speelduur gelogd',
      type: AchievementType.playtimeMinutes,
      targetCount: 30000,
    ),
    // Multi-platform
    AppAchievement(
      id: 'multi_platform',
      icon: LucideIcons.monitor,
      title: 'Multi-Platform',
      description: 'Games op 3 of meer verschillende platformen',
      type: AchievementType.platformCount,
      targetCount: 3,
    ),
    AppAchievement(
      id: 'multi_platform_5',
      icon: LucideIcons.monitor,
      title: 'Platform Hopper',
      description: 'Games op 5 of meer verschillende platformen',
      type: AchievementType.platformCount,
      targetCount: 5,
    ),
    AppAchievement(
      id: 'multi_platform_8',
      icon: LucideIcons.monitor,
      title: 'Platform Held',
      description: 'Games op 8 of meer verschillende platformen',
      type: AchievementType.platformCount,
      targetCount: 8,
    ),
    // Notes
    AppAchievement(
      id: 'notes_written',
      icon: LucideIcons.fileText,
      title: 'Kroniekschrijver',
      description: 'Schrijf een notitie bij een game',
      type: AchievementType.notesWritten,
      targetCount: 1,
    ),
    AppAchievement(
      id: 'notes_5',
      icon: LucideIcons.fileText,
      title: 'Schrijver',
      description: 'Notities geschreven bij 5 verschillende games',
      type: AchievementType.notesWritten,
      targetCount: 5,
    ),
    AppAchievement(
      id: 'notes_10',
      icon: LucideIcons.fileText,
      title: 'Verslaggever',
      description: 'Notities geschreven bij 10 verschillende games',
      type: AchievementType.notesWritten,
      targetCount: 10,
    ),
    // Tags
    AppAchievement(
      id: 'tags_first',
      icon: LucideIcons.tag,
      title: 'Goed Georganiseerd',
      description: 'Voeg een tag toe aan een game',
      type: AchievementType.tagsUsed,
      targetCount: 1,
    ),
    // Social / share
    AppAchievement(
      id: 'first_share',
      icon: LucideIcons.share2,
      title: 'Deel je Passie',
      description: 'Deel je spelvoortgang voor het eerst',
      type: AchievementType.shareCount,
      targetCount: 1,
    ),
    AppAchievement(
      id: 'share_5',
      icon: LucideIcons.share2,
      title: 'Enthousiasteling',
      description: '5 keer je voortgang gedeeld',
      type: AchievementType.shareCount,
      targetCount: 5,
    ),
    AppAchievement(
      id: 'share_10',
      icon: LucideIcons.share2,
      title: 'Community Held',
      description: '10 keer je voortgang gedeeld',
      type: AchievementType.shareCount,
      targetCount: 10,
    ),
    // Online achievements link
    AppAchievement(
      id: 'online_linked',
      icon: LucideIcons.link,
      title: 'Eerste Koppeling',
      description: 'Game met online achievements geladen',
      type: AchievementType.onlineAchievementsLoaded,
      targetCount: 1,
    ),
  ];
}

class AppAchievementProgress {
  const AppAchievementProgress({
    required this.achievement,
    required this.currentCount,
    required this.isUnlocked,
    this.unlockedAt,
    this.isNew = false,
  });

  final AppAchievement achievement;
  final int currentCount;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final bool isNew;

  double get ratio {
    if (isUnlocked) return 1.0;
    final target = achievement.targetCount;
    if (target <= 0) return 0.0;
    return (currentCount / target).clamp(0.0, 1.0);
  }

  String get progressLabel {
    if (achievement.type == AchievementType.playtimeMinutes) {
      final currentH = currentCount ~/ 60;
      final targetH = achievement.targetCount ~/ 60;
      return '$currentH / ${targetH}u';
    }
    return '$currentCount / ${achievement.targetCount}';
  }
}
