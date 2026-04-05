import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../data/app_achievement_service.dart';
import '../domain/app_achievement.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  List<AppAchievementProgress> _progress = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    DatabaseHelper.instance.addListener(_onCollectionChanged);
    // When the shell unlocks achievements, we also refresh unread state
    AppAchievementService.newlyUnlockedNotifier.addListener(
      _onCollectionChanged,
    );
  }

  @override
  void dispose() {
    DatabaseHelper.instance.removeListener(_onCollectionChanged);
    AppAchievementService.newlyUnlockedNotifier.removeListener(
      _onCollectionChanged,
    );
    super.dispose();
  }

  void _onCollectionChanged() {
    _load();
  }

  Future<void> _load() async {
    final items = await DatabaseHelper.instance.getCollectionItems();
    if (!mounted) return;

    final progress = await AppAchievementService.instance.getProgress(items);
    if (!mounted) return;

    // Mark newly seen achievements as seen when user opens this page
    if (_progress.isEmpty || progress.any((p) => p.isNew)) {
      for (final p in progress.where((p) => p.isNew)) {
        await DatabaseHelper.instance.markAppAchievementSeen(p.achievement.id);
      }
    }

    // Reload after marking seen so the "Nieuw" badges disappear
    final refreshed = await AppAchievementService.instance.getProgress(items);
    if (!mounted) return;

    setState(() {
      _progress = refreshed;
      _isLoading = false;
    });
  }

  int get _unlockedCount => _progress.where((p) => p.isUnlocked).length;
  int get _totalCount => AppAchievement.all.length;

  void _showDetail(BuildContext context, AppAchievementProgress p) {
    final achievement = p.achievement;
    final isUnlocked = p.isUnlocked;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isUnlocked ? AppTheme.orange100 : AppTheme.gray100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    achievement.icon,
                    size: 36,
                    color: isUnlocked ? AppTheme.orange500 : AppTheme.gray300,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                achievement.title,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                achievement.description,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: AppTheme.gray700,
                ),
              ),
              const SizedBox(height: 12),
              if (isUnlocked && p.unlockedAt != null) ...[
                Row(
                  children: [
                    const Icon(
                      LucideIcons.circleCheck,
                      size: 14,
                      color: AppTheme.orange500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Behaald op ${_formatDate(p.unlockedAt!)}',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        color: AppTheme.orange500,
                      ),
                    ),
                  ],
                ),
              ] else if (!isUnlocked && achievement.targetCount > 1) ...[
                Row(
                  children: [
                    const Icon(
                      LucideIcons.target,
                      size: 14,
                      color: AppTheme.gray500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      p.progressLabel,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ] else if (!isUnlocked) ...[
                const Row(
                  children: [
                    Icon(LucideIcons.lock, size: 14, color: AppTheme.gray500),
                    SizedBox(width: 6),
                    Text(
                      'Nog niet behaald',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: AppTheme.gray700),
            child: const Text(
              'Sluiten',
              style: TextStyle(fontFamily: 'Manrope'),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.orange500,
                      ),
                    )
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Text(
            'Achievements',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (!_isLoading)
            Text(
              '$_unlockedCount / $_totalCount',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.orange500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildSummaryBar(),
        const Divider(height: 1, thickness: 1, color: AppTheme.gray100),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 90),
            itemCount: _progress.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              thickness: 1,
              indent: 72,
              color: AppTheme.gray100,
            ),
            itemBuilder: (context, index) {
              return _AchievementRow(
                progress: _progress[index],
                onTap: () => _showDetail(context, _progress[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar() {
    final ratio = _totalCount > 0 ? _unlockedCount / _totalCount : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppTheme.orange100,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.orange500,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(ratio * 100).round()}% van alle achievements behaald',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: AppTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Row widget ──────────────────────────────────────────────────────────────

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.progress, required this.onTap});

  final AppAchievementProgress progress;
  final VoidCallback onTap;

  static const double _rowHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    final achievement = progress.achievement;
    final isUnlocked = progress.isUnlocked;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _rowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Badge icon
              SizedBox(
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: isUnlocked ? AppTheme.orange100 : AppTheme.gray100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    achievement.icon,
                    size: 20,
                    color: isUnlocked ? AppTheme.orange500 : AppTheme.gray300,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Title + progress
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isUnlocked ? AppTheme.black : AppTheme.gray700,
                      ),
                    ),
                    if (!isUnlocked && achievement.targetCount > 1) ...[
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress.ratio,
                          minHeight: 4,
                          backgroundColor: AppTheme.gray100,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.orange300,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        progress.progressLabel,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Status indicator
              if (isUnlocked)
                const Icon(
                  LucideIcons.circleCheck,
                  size: 20,
                  color: AppTheme.orange500,
                )
              else
                const Icon(LucideIcons.lock, size: 18, color: AppTheme.gray300),
            ],
          ),
        ),
      ),
    );
  }
}
