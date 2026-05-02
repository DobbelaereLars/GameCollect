import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/sync/auth_service.dart';
import 'core/sync/connectivity_service.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_controller.dart';
import 'features/collection/data/collection_notifier.dart';
import 'features/splash/presentation/splash_page.dart';

/// Root-widget van de GameCollect-app.
/// Levert alle gedeelde providers via [MultiProvider] en luistert op
/// [AppThemeController] voor dynamische thema-updates.
class GameCollectApp extends StatelessWidget {
  const GameCollectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // App-breed thema — al geïnitialiseerd in main.dart via singleton.
        ChangeNotifierProvider<AppThemeController>.value(
          value: AppThemeController.instance,
        ),
        // Authenticatiestatus (Firebase Auth via singleton).
        ChangeNotifierProvider<AuthService>.value(value: AuthService.instance),
        // Netwerkreachability (connectivity_plus via singleton).
        ChangeNotifierProvider<ConnectivityService>.value(
          value: ConnectivityService.instance,
        ),
        // Cloud-synchronisatiestatus (Firestore via singleton).
        ChangeNotifierProvider<SyncService>.value(value: SyncService.instance),
        // Collectielijst — de enige source-of-truth voor CollectionItems.
        ChangeNotifierProvider<CollectionNotifier>(
          create: (_) => CollectionNotifier(),
        ),
      ],
      child: Consumer<AppThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeController.mode,
            // Forceer een volledige herbouw bij helderheidswijziging zodat
            // widgets die AppTheme-getters direct aanroepen ook de juiste
            // kleuren ophalen.
            home: const SplashPage(),
          );
        },
      ),
    );
  }
}
