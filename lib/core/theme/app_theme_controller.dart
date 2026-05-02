import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Beheert de app-brede `ThemeMode` (auto/licht/donker) en biedt een
/// `effectiveBrightness` zodat statische theme-helpers (bijv. dynamische
/// kleur-getters in `AppTheme`) altijd de juiste waarde retourneren — ook
/// wanneer de gebruiker "Automatisch" kiest en het systeemthema wijzigt.
class AppThemeController extends ChangeNotifier with WidgetsBindingObserver {
  AppThemeController._();
  static final AppThemeController instance = AppThemeController._();

  static const _kThemeMode = 'theme.mode'; // 'system' | 'light' | 'dark'

  ThemeMode _mode = ThemeMode.system;
  Brightness _platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  bool _initialized = false;

  ThemeMode get mode => _mode;

  /// De daadwerkelijk te gebruiken brightness (auto wordt opgelost naar het
  /// systeemthema).
  Brightness get effectiveBrightness {
    switch (_mode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return _platformBrightness;
    }
  }

  bool get isDark => effectiveBrightness == Brightness.dark;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeMode);
    _mode = _decode(stored);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, _encode(value));
  }

  @override
  void didChangePlatformBrightness() {
    final newBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (newBrightness != _platformBrightness) {
      _platformBrightness = newBrightness;
      if (_mode == ThemeMode.system) {
        notifyListeners();
      }
    }
  }

  static ThemeMode _decode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
