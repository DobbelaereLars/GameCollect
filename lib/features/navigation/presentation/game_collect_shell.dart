import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../achievements/presentation/achievements_page.dart';
import '../../collection/presentation/collection_page.dart';
import '../../discover/presentation/discover_page.dart';
import '../../overview/presentation/overview_page.dart';
import '../../progress/presentation/progress_page.dart';
import '../domain/navigation_tab.dart';
import 'widgets/app_bottom_navigation.dart';

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) {
        return MaterialPageRoute(builder: (context) => child);
      },
    );
  }
}

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

class GameCollectShell extends StatefulWidget {
  const GameCollectShell({super.key});

  @override
  State<GameCollectShell> createState() => _GameCollectShellState();
}

class _GameCollectShellState extends State<GameCollectShell> {
  int _currentIndex = 0;
  late final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    CollectionPage.searchRequest.addListener(_onCollectionSearchRequest);
    DiscoverPage.gameDetailRequest.addListener(_onDiscoverGameDetailRequest);
  }

  @override
  void dispose() {
    CollectionPage.searchRequest.removeListener(_onCollectionSearchRequest);
    DiscoverPage.gameDetailRequest.removeListener(_onDiscoverGameDetailRequest);
    _pageController.dispose();
    super.dispose();
  }

  void _onCollectionSearchRequest() {
    if (CollectionPage.searchRequest.value != null) {
      _switchToTabAnimated(1);
    }
  }

  void _onDiscoverGameDetailRequest() {
    if (DiscoverPage.gameDetailRequest.value != null) {
      _switchToTab(2);
    }
  }

  void _switchToTab(int index) {
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  void _switchToTabAnimated(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  late final List<NavigationTab> _tabs = [
    const NavigationTab(
      label: 'Overzicht',
      icon: LucideIcons.house,
      page: _TabNavigator(child: OverviewPage()),
    ),
    const NavigationTab(
      label: 'Collectie',
      icon: LucideIcons.library,
      page: _TabNavigator(child: CollectionPage()),
    ),
    const NavigationTab(
      label: 'Ontdekken',
      icon: LucideIcons.search,
      page: _TabNavigator(child: DiscoverPage()),
    ),
    const NavigationTab(
      label: 'Voortgang',
      icon: LucideIcons.listChecks,
      page: _TabNavigator(child: ProgressPage()),
    ),
    const NavigationTab(
      label: 'Achievements',
      icon: LucideIcons.trophy,
      page: _TabNavigator(child: AchievementsPage()),
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
