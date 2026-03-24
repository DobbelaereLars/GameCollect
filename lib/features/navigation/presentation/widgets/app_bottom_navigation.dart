import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.orange500,
          unselectedItemColor: AppTheme.black,
          backgroundColor: const Color(0xF5FFFFFF),
          elevation: 0,
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
        ),
      ),
    );
  }
}
