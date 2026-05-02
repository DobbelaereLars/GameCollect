import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/collection_item.dart';

/// Beheerpagina voor achievements die niet meegeteld worden.
/// Toont alle achievements met opties om ze als voltooid te markeren of in te schakelen.
class DisabledAchievementsPage extends StatefulWidget {
  const DisabledAchievementsPage({
    super.key,
    required this.initialAchievements,
    required this.onToggleCompleted,
    required this.onToggleEnabled,
  });

  /// Initiële lijst van achievements met hun huidige status.
  final List<GameAchievementWithState> initialAchievements;

  /// Callback om een achievement als voltooid/niet-voltooid te markeren.
  final Future<void> Function(int rawgId, bool value) onToggleCompleted;

  /// Callback om een achievement in of uit te schakelen (niet meer meetellen).
  final Future<void> Function(int rawgId, bool enabled) onToggleEnabled;

  @override
  State<DisabledAchievementsPage> createState() =>
      _DisabledAchievementsPageState();
}

class _DisabledAchievementsPageState extends State<DisabledAchievementsPage> {
  late List<GameAchievementWithState> _achievements;

  @override
  void initState() {
    super.initState();
    _achievements = List<GameAchievementWithState>.from(
      widget.initialAchievements,
    );
  }

  /// Bouwt een placeholder-icoon voor achievements zonder afbeelding.
  Widget _placeholder() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.orange50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        LucideIcons.trophy,
        size: 18,
        color: AppTheme.orange300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: AppTheme.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Niet meetellen',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: AppTheme.black,
          ),
        ),
      ),
      body: _achievements.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.eye, size: 48, color: AppTheme.gray300),
                    const SizedBox(height: 16),
                    Text(
                      'Geen verborgen achievements.\nAchievements die je niet wil meetellen in je progressie vind je hier terug.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _achievements.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: AppTheme.gray100),
              itemBuilder: (context, index) {
                final achievement = _achievements[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Checkbox(
                          value: achievement.isCompleted,
                          onChanged: (value) async {
                            final newVal = value ?? false;
                            await widget.onToggleCompleted(
                              achievement.rawgId,
                              newVal,
                            );
                            if (!mounted) return;
                            setState(() {
                              _achievements[index] = achievement.copyWith(
                                isCompleted: newVal,
                              );
                            });
                          },
                          activeColor: AppTheme.orange500,
                          side: BorderSide(color: AppTheme.gray300),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: achievement.imageUrl != null
                            ? Image.network(
                                achievement.imageUrl!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _placeholder(),
                              )
                            : _placeholder(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          achievement.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                            color: AppTheme.gray500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Re-enable button
                      GestureDetector(
                        onTap: () async {
                          await widget.onToggleEnabled(
                            achievement.rawgId,
                            true,
                          );
                          if (!mounted) return;
                          setState(() => _achievements.removeAt(index));
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            LucideIcons.eye,
                            size: 18,
                            color: AppTheme.orange500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
