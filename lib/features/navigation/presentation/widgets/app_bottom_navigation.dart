import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

import '../../domain/navigation_tab.dart';

/// Onderste navigatiebalk met glazen achtergrond (backdrop blur).
/// Toont één item per [NavigationTab] en roept [onTap] aan bij selectie.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
    super.key,
  });

  /// Index van de momenteel actieve tab.
  final int currentIndex;

  /// Lijst van tabs die getoond worden.
  final List<NavigationTab> tabs;

  /// Callback die wordt aangeroepen als de gebruiker op een tab tikt.
  final ValueChanged<int> onTap;

  /// Bouwt de navigatiebalk met blur-effect en oranje accentkleur.
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
          backgroundColor: AppTheme.glassLight,
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
