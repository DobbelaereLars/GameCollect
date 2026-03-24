import 'package:flutter/widgets.dart';

class NavigationTab {
  const NavigationTab({
    required this.label,
    required this.icon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final Widget page;
}
