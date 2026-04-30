import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_controller.dart';
import 'features/navigation/presentation/game_collect_shell.dart';

class GameCollectApp extends StatelessWidget {
  const GameCollectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final brightness = AppThemeController.instance.effectiveBrightness;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: AppThemeController.instance.mode,
          // Force a full subtree rebuild on brightness change so widgets that
          // read `AppTheme.<dynamic>` getters directly (i.e. don't depend on
          // an InheritedWidget) also pick up the new colors immediately.
          home: GameCollectShell(key: ValueKey(brightness)),
        );
      },
    );
  }
}
