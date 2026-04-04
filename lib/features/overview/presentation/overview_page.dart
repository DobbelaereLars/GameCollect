import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../collection/domain/collection_item.dart';
import '../../collection/presentation/collection_page.dart';
import '../../discover/data/rawg_games_api.dart';
import '../../discover/domain/rawg_game.dart';
import '../../discover/presentation/discover_page.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  /// Set a tab index to request that the shell switches to that tab.
  /// 0 = Overzicht, 1 = Collectie, 2 = Ontdekken, 3 = Voortgang, 4 = Achievements
  static final switchToTabRequest = ValueNotifier<int?>(null);

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  // ── Collection (offline) ──────────────────────────────────────────────────
  List<CollectionItem> _collectionItems = [];
  bool _isLoadingCollection = true;

  // ── Trending games (online / RAWG) ────────────────────────────────────────
  final http.Client _httpClient = http.Client();
  final RawgGamesApi _rawgApi = const RawgGamesApi();
  List<RawgGame> _trendingGames = [];
  bool _isLoadingTrending = true;
  bool _isSlowTrending = false;
  String? _trendingError;
  Timer? _slowConnectionTimer;

  String get _rawgApiKey => dotenv.env['RAWG_API_KEY'] ?? '';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadCollection();
    _fetchTrending();
    DatabaseHelper.instance.addListener(_loadCollection);
  }

  @override
  void dispose() {
    _slowConnectionTimer?.cancel();
    _httpClient.close();
    DatabaseHelper.instance.removeListener(_loadCollection);
    super.dispose();
  }

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _loadCollection() async {
    if (!mounted) return;
    final items = await DatabaseHelper.instance.getCollectionItems();
    if (!mounted) return;
    setState(() {
      _collectionItems = items;
      _isLoadingCollection = false;
    });
  }

  Future<void> _fetchTrending() async {
    if (_rawgApiKey.isEmpty) {
      setState(() {
        _trendingError = 'Er is iets misgegaan.';
        _isLoadingTrending = false;
      });
      return;
    }

    setState(() {
      _isLoadingTrending = true;
      _trendingError = null;
      _isSlowTrending = false;
    });

    _slowConnectionTimer?.cancel();
    _slowConnectionTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoadingTrending) {
        setState(() => _isSlowTrending = true);
      }
    });

    try {
      final page = await _rawgApi.fetchTopRatedGames(
        client: _httpClient,
        apiKey: _rawgApiKey,
        pageSize: 12,
      );
      _slowConnectionTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _trendingGames = page.games
            .where((g) => g.coverUrl != null && g.coverUrl!.isNotEmpty)
            .toList();
        _isLoadingTrending = false;
        _isSlowTrending = false;
      });
    } catch (e) {
      _slowConnectionTimer?.cancel();
      if (!mounted) return;
      final isNetworkError =
          e is SocketException ||
          e is TimeoutException ||
          e.toString().contains('SocketException') ||
          e.toString().contains('ClientException');
      setState(() {
        _trendingError = isNetworkError
            ? 'Controleer je internetverbinding'
            : 'Er is iets misgegaan.';
        _isLoadingTrending = false;
        _isSlowTrending = false;
      });
    }
  }

  // ── Computed properties ───────────────────────────────────────────────────

  int get _totalUniqueGames =>
      _collectionItems.map((e) => e.apiId).toSet().length;

  int get _totalPlaytimeMinutes =>
      _collectionItems.fold(0, (sum, item) => sum + item.totalPlaytimeMinutes);

  int get _completedCount => _collectionItems
      .where((item) => item.isManuallyCompleted || item.progressRatio >= 1.0)
      .map((e) => e.apiId)
      .toSet()
      .length;

  /// Unique games from collection (first occurrence per apiId), max 10.
  /// Each entry carries allItems (all platform entries for same apiId) so
  /// the card can show platform badges.
  List<_GameGroup> get _recentGroups {
    final seen = <int>{};
    final result = <_GameGroup>[];
    for (final item in _collectionItems) {
      if (!seen.contains(item.apiId)) {
        seen.add(item.apiId);
        final allForGame = _collectionItems
            .where((e) => e.apiId == item.apiId)
            .toList(growable: false);
        result.add(_GameGroup(representative: item, allItems: allForGame));
      }
    }
    return result.take(10).toList();
  }

  /// Games with ANY platform that has playtime > 0, not yet completed,
  /// AND a playtime entry added within the last 5 days. Sorted by total playtime desc.
  List<_GameGroup> get _inProgressGroups {
    final seen = <int>{};
    final candidates = <_GameGroup>[];
    final cutoff = DateTime.now().subtract(const Duration(days: 5));
    for (final item in _collectionItems) {
      if (!seen.contains(item.apiId)) {
        final allForGame = _collectionItems
            .where((e) => e.apiId == item.apiId)
            .toList(growable: false);
        final totalMinutes = allForGame.fold<int>(
          0,
          (sum, e) => sum + e.totalPlaytimeMinutes,
        );
        final isCompleted = allForGame.every(
          (e) => e.isManuallyCompleted || e.progressRatio >= 1.0,
        );
        final hasRecentEntry = allForGame.any(
          (e) => e.playtimeEntries.any((p) => p.addedAt.isAfter(cutoff)),
        );
        if (totalMinutes > 0 && !isCompleted && hasRecentEntry) {
          seen.add(item.apiId);
          candidates.add(
            _GameGroup(representative: item, allItems: allForGame),
          );
        }
      }
    }
    candidates.sort((a, b) {
      final aTotal = a.allItems.fold<int>(
        0,
        (s, e) => s + e.totalPlaytimeMinutes,
      );
      final bTotal = b.allItems.fold<int>(
        0,
        (s, e) => s + e.totalPlaytimeMinutes,
      );
      return bTotal.compareTo(aTotal);
    });
    return candidates.take(8).toList();
  }

  /// Total minutes from playtime entries added in the last 7 days.
  int get _last7DaysMinutes {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _collectionItems.fold<int>(
      0,
      (sum, item) =>
          sum +
          item.playtimeEntries
              .where((e) => e.addedAt.isAfter(cutoff))
              .fold<int>(0, (s, e) => s + e.minutes),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatMinutes(int minutes) {
    if (minutes == 0) return '0 min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '${h}u';
    return '${h}u ${m}m';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Goedemorgen';
    if (hour < 18) return 'Goedemiddag';
    return 'Goedenavond';
  }

  void _navigateToDetail(CollectionItem item) {
    if (item.id == null) return;
    CollectionPage.itemDetailRequest.value = item.id;
  }

  void _navigateToGame(RawgGame game) {
    DiscoverPage.gameDetailRequest.value = (
      gameId: game.id,
      fallbackTitle: game.title,
      fallbackCoverUrl: game.coverUrl,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // ── Greeting ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: textTheme.headlineMedium?.copyWith(
                        color: AppTheme.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hier is je game-overzicht',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTheme.gray500,
                      ),
                    ),
                    if (!_isLoadingCollection) ...[
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _StatChip(
                              icon: LucideIcons.library,
                              label:
                                  '$_totalUniqueGames ${_totalUniqueGames == 1 ? 'game' : 'games'}',
                            ),
                            const SizedBox(width: 8),
                            _StatChip(
                              icon: LucideIcons.clock,
                              label: _formatMinutes(_totalPlaytimeMinutes),
                            ),
                            if (_completedCount > 0) ...[
                              const SizedBox(width: 8),
                              _StatChip(
                                icon: LucideIcons.trophy,
                                label: '$_completedCount voltooid',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Mijn collectie ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    title: 'Mijn collectie',
                    actionLabel:
                        (!_isLoadingCollection && _collectionItems.isNotEmpty)
                        ? 'Bekijk alles'
                        : null,
                    onAction: () => OverviewPage.switchToTabRequest.value = 1,
                  ),
                  if (_isLoadingCollection)
                    const _HorizontalLoadingPlaceholder()
                  else if (_collectionItems.isEmpty)
                    _EmptyCollectionCard()
                  else
                    _HorizontalGroupList(
                      groups: _recentGroups,
                      showProgress: false,
                      formatMinutes: _formatMinutes,
                      onTap: _navigateToDetail,
                    ),
                ],
              ),
            ),

            // ── Bezig met spelen (conditioneel) ───────────────────────────
            if (!_isLoadingCollection && _inProgressGroups.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(title: 'Bezig met spelen'),
                    _HorizontalGroupList(
                      groups: _inProgressGroups,
                      showProgress: true,
                      formatMinutes: _formatMinutes,
                      onTap: _navigateToDetail,
                    ),
                  ],
                ),
              ),

            // ── Speelduur samenvatting ────────────────────────────────────
            if (!_isLoadingCollection && _last7DaysMinutes > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _PlaytimeSummaryCard(
                    weekMinutes: _last7DaysMinutes,
                    formatMinutes: _formatMinutes,
                  ),
                ),
              ),

            // ── Trending games (online) ───────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    title: 'Trending games',
                    actionLabel: (!_isLoadingTrending && _trendingError == null)
                        ? 'Ontdekken'
                        : null,
                    onAction: () => OverviewPage.switchToTabRequest.value = 2,
                  ),
                  if (_isLoadingTrending)
                    _HorizontalLoadingPlaceholder(
                      showSlowMessage: _isSlowTrending,
                    )
                  else if (_trendingError != null)
                    _SectionErrorCard(
                      error: _trendingError!,
                      onRetry: _fetchTrending,
                    )
                  else
                    _HorizontalTrendingList(
                      games: _trendingGames,
                      onTap: _navigateToGame,
                    ),
                ],
              ),
            ),

            // Bottom padding for the nav bar
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.black,
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: textTheme.bodySmall?.copyWith(
                  color: AppTheme.orange500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.orange50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.orange700),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppTheme.orange700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal loading placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _HorizontalLoadingPlaceholder extends StatelessWidget {
  const _HorizontalLoadingPlaceholder({this.showSlowMessage = false});

  final bool showSlowMessage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.orange500),
            if (showSlowMessage) ...[
              const SizedBox(height: 12),
              Text(
                'Dit duurt langer dan normaal...',
                style: textTheme.bodyMedium?.copyWith(color: AppTheme.gray700),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty collection card
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyCollectionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.orange50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.orange100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                LucideIcons.library,
                size: 24,
                color: AppTheme.orange500,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Je collectie is nog leeg',
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Voeg games toe via de Ontdekken tab',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section error card (inline, compact)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionErrorCard extends StatelessWidget {
  const _SectionErrorCard({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isNetworkError = error == 'Controleer je internetverbinding';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isNetworkError ? LucideIcons.wifiOff : LucideIcons.triangleAlert,
            size: 48,
            color: AppTheme.orange500,
          ),
          const SizedBox(height: 12),
          Text(
            error,
            style: textTheme.bodyMedium?.copyWith(color: AppTheme.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.orange500,
              side: const BorderSide(color: AppTheme.orange500),
            ),
            child: const Text('Opnieuw proberen'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GameGroup data class – groups all platform entries for one game
// ─────────────────────────────────────────────────────────────────────────────

class _GameGroup {
  const _GameGroup({required this.representative, required this.allItems});

  /// The first/primary CollectionItem (used for cover, title, apiId).
  final CollectionItem representative;

  /// All platform entries for this game (may be 1 or more).
  final List<CollectionItem> allItems;
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal game list (collection groups)
// ─────────────────────────────────────────────────────────────────────────────

class _HorizontalGroupList extends StatelessWidget {
  const _HorizontalGroupList({
    required this.groups,
    required this.onTap,
    required this.formatMinutes,
    this.showProgress = false,
  });

  final List<_GameGroup> groups;
  final void Function(CollectionItem item) onTap;
  final String Function(int) formatMinutes;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    // Extra 16 px reserved for dot indicators (always, so covers are uniform).
    final double height = showProgress ? 226 : 210;
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index == groups.length - 1 ? 0 : 12,
            ),
            child: _CollectionGameCard(
              group: group,
              showProgress: showProgress,
              formatMinutes: formatMinutes,
              onTap: onTap,
            ),
          );
        },
      ),
    );
  }
}

class _CollectionGameCard extends StatefulWidget {
  const _CollectionGameCard({
    required this.group,
    required this.showProgress,
    required this.formatMinutes,
    required this.onTap,
  });

  final _GameGroup group;
  final bool showProgress;
  final String Function(int) formatMinutes;
  final void Function(CollectionItem item) onTap;

  @override
  State<_CollectionGameCard> createState() => _CollectionGameCardState();
}

class _CollectionGameCardState extends State<_CollectionGameCard> {
  int _selectedIndex = 0;
  bool _forward = true;
  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();
    _startCycleIfNeeded();
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  void _startCycleIfNeeded() {
    _cycleTimer?.cancel();
    if (_eligibleItems.length <= 1) return;
    _cycleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _forward = true;
        _selectedIndex = (_selectedIndex + 1) % _eligibleItems.length;
      });
    });
  }

  List<CollectionItem> get _eligibleItems {
    if (widget.showProgress) {
      // For "bezig met spelen": only platforms with playtime
      final withPlaytime = widget.group.allItems
          .where((e) => e.totalPlaytimeMinutes > 0)
          .toList(growable: false);
      return withPlaytime.isNotEmpty ? withPlaytime : widget.group.allItems;
    }
    // For "mijn collectie": all platforms
    return widget.group.allItems;
  }

  CollectionItem get _current {
    final items = _eligibleItems;
    final idx = _selectedIndex.clamp(0, items.length - 1);
    return items[idx];
  }

  String _cleanPlatformName(String raw) {
    return raw.replaceAll(RegExp(r'\s*\([^)]*\)$'), '').trim();
  }

  Widget _coverWidget(CollectionItem item) {
    if (item.customCoverPath != null) {
      return SizedBox.expand(
        child: Image.file(
          File(item.customCoverPath!),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (ctx, err, stack) => const Center(
            child: Icon(
              LucideIcons.gamepad2,
              size: 32,
              color: AppTheme.gray300,
            ),
          ),
        ),
      );
    }
    if (item.coverUrl != null) {
      return SizedBox.expand(
        child: Image.network(
          item.coverUrl!,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => const Center(
            child: Icon(
              LucideIcons.gamepad2,
              size: 32,
              color: AppTheme.gray300,
            ),
          ),
        ),
      );
    }
    return const Center(
      child: Icon(LucideIcons.gamepad2, size: 32, color: AppTheme.gray300),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final items = _eligibleItems;
    final hasMultiple = items.length > 1;
    final current = _current;
    final platformName = current.selectedPlatforms.isNotEmpty
        ? _cleanPlatformName(current.selectedPlatforms.first)
        : null;

    return GestureDetector(
      onTap: () => widget.onTap(current),
      child: SizedBox(
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with badge and title overlaid
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Swipe animation on platform switch
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        transitionBuilder: (child, animation) {
                          // AnimatedSwitcher reverses the animation for the
                          // outgoing child (1→0), so both begin/end use
                          // Offset.zero as the "resting" position:
                          // • incoming: begin=(±1,0) → end=(0,0)  [0→1]
                          // • outgoing: end=(0,0) stays; begin=(∓1,0)  [1→0 → drifts off]
                          final dir = _forward ? 1.0 : -1.0;
                          final isIncoming =
                              child.key == ValueKey(_selectedIndex);
                          final curved = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          );
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: isIncoming
                                  ? Offset(dir, 0.0)
                                  : Offset(-dir, 0.0),
                              end: Offset.zero,
                            ).animate(curved),
                            child: child,
                          );
                        },
                        child: Container(
                          key: ValueKey(_selectedIndex),
                          color: AppTheme.orange50,
                          child: _coverWidget(current),
                        ),
                      ),
                    ),

                    // Top-left badges: platform (multi only) + playtime (in-progress only)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (platformName != null) ...[
                            _CoverBadge(
                              icon: LucideIcons.gamepad2,
                              label: platformName.isNotEmpty
                                  ? platformName
                                  : '?',
                            ),
                            const SizedBox(height: 5),
                          ],
                          if (widget.showProgress &&
                              current.totalPlaytimeMinutes > 0)
                            _CoverBadge(
                              icon: LucideIcons.clock,
                              label: widget.formatMinutes(
                                current.totalPlaytimeMinutes,
                              ),
                              filled: true,
                            ),
                        ],
                      ),
                    ),

                    // Bottom gradient + title + optional playtime
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.blackTransparent0,
                              AppTheme.blackTransparent80,
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              current.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.white,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dot indicators – 16 px slot always reserved to keep all card
            // heights uniform; filled only when there are multiple platforms.
            SizedBox(
              height: 16,
              child: hasMultiple
                  ? Align(
                      alignment: Alignment.bottomCenter,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(items.length, (i) {
                          final isActive = i == _selectedIndex;
                          return GestureDetector(
                            onTap: () {
                              _cycleTimer?.cancel();
                              setState(() {
                                _forward = i > _selectedIndex;
                                _selectedIndex = i;
                              });
                              Future.delayed(const Duration(seconds: 4), () {
                                if (mounted) _startCycleIfNeeded();
                              });
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isActive ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppTheme.orange500
                                      : AppTheme.orange200,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Progress bar
            if (widget.showProgress) ...[
              const SizedBox(height: 6),
              _MiniProgressBar(ratio: current.progressRatio),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small badge used on top of card covers (platform + playtime)
// ─────────────────────────────────────────────────────────────────────────────

class _CoverBadge extends StatelessWidget {
  const _CoverBadge({
    required this.icon,
    required this.label,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bgColor = filled ? AppTheme.orange500 : AppTheme.orange50;
    final iconColor = filled ? AppTheme.white : AppTheme.orange500;
    final textColor = filled ? AppTheme.white : AppTheme.orange700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.orange100,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.orange500,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Playtime summary card
// ─────────────────────────────────────────────────────────────────────────────

class _PlaytimeSummaryCard extends StatelessWidget {
  const _PlaytimeSummaryCard({
    required this.weekMinutes,
    required this.formatMinutes,
  });

  final int weekMinutes;
  final String Function(int) formatMinutes;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.orange50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.orange100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.calendarDays,
              size: 22,
              color: AppTheme.orange500,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Afgelopen 7 dagen',
                style: textTheme.bodySmall?.copyWith(
                  color: AppTheme.orange700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatMinutes(weekMinutes),
                    style: textTheme.titleLarge?.copyWith(
                      color: AppTheme.orange500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'gespeeld',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.orange700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal trending list (RAWG games)
// ─────────────────────────────────────────────────────────────────────────────

class _HorizontalTrendingList extends StatelessWidget {
  const _HorizontalTrendingList({required this.games, required this.onTap});

  final List<RawgGame> games;
  final void Function(RawgGame game) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 194,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          return Padding(
            padding: EdgeInsets.only(right: index == games.length - 1 ? 0 : 12),
            child: GestureDetector(
              onTap: () => onTap(game),
              child: _TrendingGameCard(game: game),
            ),
          );
        },
      ),
    );
  }
}

class _TrendingGameCard extends StatelessWidget {
  const _TrendingGameCard({required this.game});

  final RawgGame game;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 128,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: AppTheme.orange50,
              child: game.coverUrl != null
                  ? Image.network(
                      game.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, error, stack) => const Center(
                        child: Icon(
                          LucideIcons.gamepad2,
                          size: 32,
                          color: AppTheme.gray300,
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        LucideIcons.gamepad2,
                        size: 32,
                        color: AppTheme.gray300,
                      ),
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.blackTransparent0,
                      AppTheme.blackTransparent80,
                    ],
                  ),
                ),
                child: Text(
                  game.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
