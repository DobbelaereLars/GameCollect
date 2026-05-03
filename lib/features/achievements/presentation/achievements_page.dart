import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../data/app_achievement_service.dart';
import '../domain/app_achievement.dart';

/// Overzichtspagina voor alle app-achievements: geeft voortgang en detail-dialogen.
class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  /// Signaal om de lijst terug naar boven te scrollen (bijv. bij dubbel tappen op de tab).
  static final scrollToTopRequest = ValueNotifier<int>(0);

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  final ScrollController _scrollController = ScrollController();
  List<AppAchievementProgress> _progress = [];
  bool _isLoading = true;
  int _loadGeneration = 0;

  /// Initialiseert de pagina: laadt achievement-voortgang en registreert listeners.
  @override
  void initState() {
    super.initState();
    _load();
    DatabaseHelper.instance.addListener(_onCollectionChanged);
    AchievementsPage.scrollToTopRequest.addListener(_onScrollToTop);
    // Als de shell achievements ontgrendelt, wordt de lijst ook ververst.
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
    AchievementsPage.scrollToTopRequest.removeListener(_onScrollToTop);
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrollt de lijst naar boven als het signaal wordt ontvangen.
  void _onScrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Herlaadt de voortgang als de collectie gewijzigd is.
  void _onCollectionChanged() {
    _load();
  }

  /// Laadt de achievement-voortgang vanuit de database en markeert nieuwe als gezien.
  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final items = await DatabaseHelper.instance.getCollectionItems();
    if (!mounted || generation != _loadGeneration) return;

    final progress = await AppAchievementService.instance.getProgress(items);
    if (!mounted || generation != _loadGeneration) return;

    // Markeer nieuw ontgrendelde achievements als gezien zodra de gebruiker deze pagina opent.
    if (_progress.isEmpty || progress.any((p) => p.isNew)) {
      for (final p in progress.where((p) => p.isNew)) {
        await DatabaseHelper.instance.markAppAchievementSeen(p.achievement.id);
      }
    }

    // Herlaad na markering zodat de 'Nieuw'-badges verdwijnen.
    final refreshed = await AppAchievementService.instance.getProgress(items);
    if (!mounted || generation != _loadGeneration) return;

    setState(() {
      _progress = refreshed;
      _isLoading = false;
    });
  }

  /// Aantal behaalde achievements.
  int get _unlockedCount => _progress.where((p) => p.isUnlocked).length;

  /// Totaal aantal beschikbare achievements.
  int get _totalCount => AppAchievement.all.length;

  /// Toont het detaildialoog voor een achievement.
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
                style: TextStyle(
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
                style: TextStyle(
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
                    Icon(LucideIcons.target, size: 14, color: AppTheme.gray500),
                    const SizedBox(width: 6),
                    Text(
                      p.progressLabel,
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
              ] else if (!isUnlocked) ...[
                Row(
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
        Divider(height: 1, thickness: 1, color: AppTheme.gray100),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 90),
            itemCount: _progress.length,
            separatorBuilder: (context, index) => Divider(
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
            style: TextStyle(
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
              // Badge-icoon voor het achievement.
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
              // Titel en voortgangsindicator.
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
                        style: TextStyle(
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
              // Statusindicator: vinkje als behaald, slot als nog niet behaald.
              if (isUnlocked)
                const Icon(
                  LucideIcons.circleCheck,
                  size: 20,
                  color: AppTheme.orange500,
                )
              else
                Icon(LucideIcons.lock, size: 18, color: AppTheme.gray300),
            ],
          ),
        ),
      ),
    );
  }
}
