import 'package:flutter/material.dart';

import '../../domain/navigation_tab.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final List<NavigationTab> tabs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFFFF6B00),
      unselectedItemColor: const Color(0xFF000000),
      backgroundColor: const Color(0xFFFFFFFF),
      showUnselectedLabels: true,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      onTap: onTap,
      items: tabs
          .map(
            (tab) => BottomNavigationBarItem(
              icon: Icon(tab.icon, size: 20),
              label: tab.label,
            ),
          )
          .toList(),
    );
  }
}
