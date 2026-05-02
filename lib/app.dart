import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_controller.dart';
import 'features/splash/presentation/splash_page.dart';

/// Root-widget van de GameCollect-app.
/// Luistert op [AppThemeController] en past het thema dynamisch aan.
class GameCollectApp extends StatelessWidget {
  const GameCollectApp({super.key});

  /// Bouwt de [MaterialApp] met licht/donker thema op basis van de gebruikersvoorkeur.
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: AppThemeController.instance.mode,
          // Forceer een volledige herbouw bij helderheidswijziging zodat widgets
          // die AppTheme-getters direct aanroepen (zonder InheritedWidget)
          // ook direct de juiste kleuren ophalen.
          home: const SplashPage(),
        );
      },
    );
  }
}
