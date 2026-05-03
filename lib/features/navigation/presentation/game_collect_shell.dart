import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../achievements/data/app_achievement_service.dart';
import '../../achievements/domain/app_achievement.dart';
import '../../achievements/presentation/achievements_page.dart';
import '../../collection/presentation/collection_page.dart';
import '../../discover/presentation/discover_page.dart';
import '../../overview/presentation/overview_page.dart';
import '../domain/navigation_tab.dart';
import 'widgets/app_bottom_navigation.dart';

/// Interne helper die een tabinhoud inpakt in een eigen Navigator voor deep navigation.
class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.child, this.navigatorKey});

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(builder: (context) => child);
      },
    );
  }
}

/// Interne helper die een widget levend houdt via [AutomaticKeepAliveClientMixin].
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});
  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Hoofdschil van de app: beheert de tabnavigatie, PageController en globale notifiers.
class GameCollectShell extends StatefulWidget {
  const GameCollectShell({super.key});

  @override
  State<GameCollectShell> createState() => _GameCollectShellState();
}

class _GameCollectShellState extends State<GameCollectShell> {
  int _currentIndex = 0;
  late final PageController _pageController = PageController();
  final _overviewNavKey = GlobalKey<NavigatorState>();
  final _collectionNavKey = GlobalKey<NavigatorState>();
  final _discoverNavKey = GlobalKey<NavigatorState>();
  final _achievementsNavKey = GlobalKey<NavigatorState>();

  /// Geordende lijst van navigator-sleutels, één per tabblad.
  late final List<GlobalKey<NavigatorState>> _navKeys = [
    _overviewNavKey,
    _collectionNavKey,
    _discoverNavKey,
    _achievementsNavKey,
  ];

  Timer? _achievementDebounce;

  @override
  void initState() {
    super.initState();
    CollectionPage.searchRequest.addListener(_onCollectionSearchRequest);
    CollectionPage.itemDetailRequest.addListener(
      _onCollectionItemDetailRequest,
    );
    DiscoverPage.gameDetailRequest.addListener(_onDiscoverGameDetailRequest);
    OverviewPage.switchToTabRequest.addListener(_onOverviewSwitchToTabRequest);
    DatabaseHelper.instance.addListener(_onCollectionChangedForAchievements);
    AppAchievementService.newlyUnlockedNotifier.addListener(
      _onAchievementsUnlocked,
    );
  }

  @override
  void dispose() {
    CollectionPage.searchRequest.removeListener(_onCollectionSearchRequest);
    CollectionPage.itemDetailRequest.removeListener(
      _onCollectionItemDetailRequest,
    );
    DiscoverPage.gameDetailRequest.removeListener(_onDiscoverGameDetailRequest);
    OverviewPage.switchToTabRequest.removeListener(
      _onOverviewSwitchToTabRequest,
    );
    DatabaseHelper.instance.removeListener(_onCollectionChangedForAchievements);
    AppAchievementService.newlyUnlockedNotifier.removeListener(
      _onAchievementsUnlocked,
    );
    _achievementDebounce?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Luistert naar databasewijzigingen en controleert achievements via debounce.
  void _onCollectionChangedForAchievements() {
    _achievementDebounce?.cancel();
    _achievementDebounce = Timer(const Duration(milliseconds: 300), () async {
      final items = await DatabaseHelper.instance.getCollectionItems();
      await AppAchievementService.instance.checkAndUnlock(items);
    });
  }

  /// Toont een snackbar voor pas ontgrendelde achievements en wist de notifier.
  void _onAchievementsUnlocked() {
    final unlocked = AppAchievementService.newlyUnlockedNotifier.value;
    if (unlocked.isEmpty || !mounted) return;
    // Meteen wissen zodat het niet opnieuw wordt afgevuurd.
    AppAchievementService.newlyUnlockedNotifier.value = [];
    _showAchievementSnackBar(unlocked);
  }

  /// Toont een achievement-snackbar met de naam (of het aantal) van de behaalde achievements.
  void _showAchievementSnackBar(List<AppAchievement> achievements) {
    final count = achievements.length;
    final message = count == 1
        ? 'Achievement behaald: ${achievements.first.title}'
        : '$count nieuwe achievements behaald!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(LucideIcons.trophy, size: 18, color: AppTheme.trueWhite),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Schakelt naar het collectietabblad als er een zoekverzoek binnenkomt.
  void _onCollectionSearchRequest() {
    if (CollectionPage.searchRequest.value != null) {
      _switchToTabAnimated(1);
    }
  }

  /// Schakelt naar het collectietabblad als er een itemdetailverzoek binnenkomt.
  void _onCollectionItemDetailRequest() {
    if (CollectionPage.itemDetailRequest.value != null) {
      _switchToTab(1);
    }
  }

  /// Schakelt naar het ontdekkingstabblad als er een speldetailverzoek binnenkomt.
  void _onDiscoverGameDetailRequest() {
    if (DiscoverPage.gameDetailRequest.value != null) {
      _switchToTab(2);
    }
  }

  /// Verwerkt tab-schakelverzoeken vanuit het overzicht.
  void _onOverviewSwitchToTabRequest() {
    final index = OverviewPage.switchToTabRequest.value;
    if (index != null) {
      OverviewPage.switchToTabRequest.value = null;
      if (index == 1) {
        _collectionNavKey.currentState?.popUntil((r) => r.isFirst);
      } else if (index == 2) {
        _discoverNavKey.currentState?.popUntil((r) => r.isFirst);
      }
      _switchToTabAnimated(index);
    }
  }

  /// Schakelt direct naar het opgegeven tabblad (zonder animatie).
  void _switchToTab(int index) {
    if (index == _currentIndex) {
      // Al op dit tabblad: navigeer terug naar root en scroll naar boven.
      _navKeys[index].currentState?.popUntil((r) => r.isFirst);
      _scrollToTopForTab(index);
      return;
    }
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  /// Stuurt een scroll-naar-boven-verzoek naar het actieve tabblad.
  void _scrollToTopForTab(int index) {
    final requests = [
      OverviewPage.scrollToTopRequest,
      CollectionPage.scrollToTopRequest,
      DiscoverPage.scrollToTopRequest,
      AchievementsPage.scrollToTopRequest,
    ];
    if (index < requests.length) requests[index].value++;
  }

  /// Schakelt met animatie naar het opgegeven tabblad.
  void _switchToTabAnimated(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  late final List<NavigationTab> _tabs = [
    NavigationTab(
      label: 'Overzicht',
      icon: LucideIcons.house,
      page: _TabNavigator(
        navigatorKey: _overviewNavKey,
        child: const OverviewPage(),
      ),
    ),
    NavigationTab(
      label: 'Collectie',
      icon: LucideIcons.library,
      page: _TabNavigator(
        navigatorKey: _collectionNavKey,
        child: const CollectionPage(),
      ),
    ),
    NavigationTab(
      label: 'Ontdekken',
      icon: LucideIcons.search,
      page: _TabNavigator(
        navigatorKey: _discoverNavKey,
        child: const DiscoverPage(),
      ),
    ),
    NavigationTab(
      label: 'Achievements',
      icon: LucideIcons.trophy,
      page: _TabNavigator(
        navigatorKey: _achievementsNavKey,
        child: const AchievementsPage(),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _tabs.map((tab) => _KeepAlivePage(child: tab.page)).toList(),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        tabs: _tabs,
        onTap: _switchToTab,
      ),
    );
  }
}
