import 'package:flutter/widgets.dart';

/// Datamodel voor één navigatietab: label, icoon en de bijbehorende pagina-widget.
class NavigationTab {
  const NavigationTab({
    required this.label,
    required this.icon,
    required this.page,
  });

  /// Zichtbaar label onder het icoon in de navigatiebalk.
  final String label;

  /// Icoondata voor de tab.
  final IconData icon;

  /// Widget die getoond wordt als deze tab actief is.
  final Widget page;
}
