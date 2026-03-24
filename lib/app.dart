import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/navigation/presentation/game_collect_shell.dart';

class GameCollectApp extends StatelessWidget {
  const GameCollectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const GameCollectShell(),
    );
  }
}
