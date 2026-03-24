import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../achievements/presentation/achievements_page.dart';
import '../../collection/presentation/collection_page.dart';
import '../../discover/presentation/discover_page.dart';
import '../../overview/presentation/overview_page.dart';
import '../../progress/presentation/progress_page.dart';
import '../domain/navigation_tab.dart';
import 'widgets/app_bottom_navigation.dart';

class GameCollectShell extends StatefulWidget {
  const GameCollectShell({super.key});

  @override
  State<GameCollectShell> createState() => _GameCollectShellState();
}

class _GameCollectShellState extends State<GameCollectShell> {
  int _currentIndex = 0;

  late final List<NavigationTab> _tabs = const [
    NavigationTab(
      label: 'Overzicht',
      icon: LucideIcons.house,
      page: OverviewPage(),
    ),
    NavigationTab(
      label: 'Collectie',
      icon: LucideIcons.library,
      page: CollectionPage(),
    ),
    NavigationTab(
      label: 'Ontdekken',
      icon: LucideIcons.search,
      page: DiscoverPage(),
    ),
    NavigationTab(
      label: 'Voortgang',
      icon: LucideIcons.listChecks,
      page: ProgressPage(),
    ),
    NavigationTab(
      label: 'Achievements',
      icon: LucideIcons.trophy,
      page: AchievementsPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs.map((tab) => tab.page).toList(),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        tabs: _tabs,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
