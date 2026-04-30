import 'package:flutter/material.dart';

import 'app_theme_controller.dart';

class AppTheme {
  AppTheme._();

  // ── Helpers ──────────────────────────────────────────────────────────────

  static bool get _isDark => AppThemeController.instance.isDark;

  // ── Brightness-aware "core" colors ───────────────────────────────────────
  // Bewust dezelfde namen als voorheen (white/black/gray*). In dark mode
  // wordt de semantiek aangehouden:
  //   - white  → primaire achtergrond
  //   - black  → primaire tekst
  //   - gray100→ subtiele rand/divider/oppervlak
  //   - gray300→ uitgeschakeld icoon
  //   - gray500→ secundaire (mid) tekst
  //   - gray700→ tertiaire tekst (iets prominenter dan 500)
  //   - gray900→ donkerste tekst (kop op een licht oppervlak)

  // Light defaults
  static const Color _whiteLight = Color(0xFFFFFFFF);
  static const Color _blackLight = Color(0xFF000000);
  static const Color _gray900Light = Color(0xFF1A1A1A);
  static const Color _gray700Light = Color(0xFF4D4D4D);
  static const Color _gray500Light = Color(0xFF808080);
  static const Color _gray300Light = Color(0xFFB3B3B3);
  static const Color _gray100Light = Color(0xFFE6E6E6);
  // Glass overlay (gebruikt door bottom-nav en search-headers).
  // In dark mode kiezen we exact het scaffold-zwart, anders krijg je een
  // zichtbare lichtere band onder/boven de pagina-content.
  static const Color _glassLightLight = Color(0xF5FFFFFF);

  // Dark equivalents (handmatig gekozen voor goed contrast op #121212 bg)
  static const Color _whiteDark = Color(0xFF121212); // achtergrond
  static const Color _blackDark = Color(0xFFF2F2F2); // primaire tekst
  static const Color _gray900Dark = Color(0xFFE6E6E6);
  static const Color _gray700Dark = Color(0xFFBFBFBF);
  static const Color _gray500Dark = Color(0xFF999999);
  static const Color _gray300Dark = Color(0xFF666666);
  static const Color _gray100Dark = Color(0xFF2A2A2A); // divider/border
  static const Color _glassLightDark = Color(0xF51E1E1E);

  static Color get white => _isDark ? _whiteDark : _whiteLight;
  static Color get black => _isDark ? _blackDark : _blackLight;
  static Color get gray900 => _isDark ? _gray900Dark : _gray900Light;
  static Color get gray700 => _isDark ? _gray700Dark : _gray700Light;
  static Color get gray500 => _isDark ? _gray500Dark : _gray500Light;
  static Color get gray300 => _isDark ? _gray300Dark : _gray300Light;
  static Color get gray100 => _isDark ? _gray100Dark : _gray100Light;
  static Color get glassLight => _isDark ? _glassLightDark : _glassLightLight;

  // Echte zwarte/witte kleuren voor overlays die ALTIJD die kleur moeten
  // hebben (bijv. donkere gradient onderaan een cover-image).
  static const Color trueBlack = Color(0xFF000000);
  static const Color trueWhite = Color(0xFFFFFFFF);

  // ── Orange palette ───────────────────────────────────────────────────────
  // De primaire accent (orange500) en alle "diepere" tinten (300-900) blijven
  // identiek tussen licht en donker — die werken goed op beide oppervlakken.
  // De pale tinten (50/100/200) worden in dark mode wel donkerder/warmer
  // gemaakt, anders worden ze felle, te lichte vlakken op een donkere bg.

  static const Color _orange50Light = Color(0xFFFFF4EB);
  static const Color _orange100Light = Color(0xFFFFE2CC);
  static const Color _orange200Light = Color(0xFFFFC299);

  // Dark equivalents: warm getinte donkere oppervlakken die goed combineren
  // met orange500 als accent/tekst. Iets lichter gekozen dan strict #1F141A,
  // zodat een orange50-pill (bv. zoekbalk) duidelijk afsteekt tegen het
  // donkere scaffold (#121212).
  static const Color _orange50Dark = Color(0xFF3D2A1A); // subtle accent bg
  static const Color _orange100Dark = Color(0xFF4D3522); // chip / button bg
  static const Color _orange200Dark = Color(0xFF6B4426); // border / divider

  static Color get orange50 => _isDark ? _orange50Dark : _orange50Light;
  static Color get orange100 => _isDark ? _orange100Dark : _orange100Light;
  static Color get orange200 => _isDark ? _orange200Dark : _orange200Light;

  // Track-kleur voor LinearProgressIndicator in beide thema's.
  // Light: pale-orange (orange100). Dark: een transparante orange500-tint
  // zodat de bar duidelijk "oranje" leest in plaats van bruin.
  static Color get progressTrack =>
      _isDark ? const Color(0x33FF6B00) : _orange100Light;

  static const Color orange300 = Color(0xFFFFA266);
  static const Color orange400 = Color(0xFFFF8A3D);
  static const Color orange500 = Color(0xFFFF6B00); // Primary accent
  static const Color orange600 = Color(0xFFE65F00);

  // orange700 wordt veel gebruikt voor accent-tekst op pale-orange chips.
  // In dark mode is dat te donker; we wisselen daar naar een lichtere
  // accent-tint zodat de tekst leesbaar blijft op de donkere chip-bg.
  static const Color _orange700Light = Color(0xFFB84C00);
  static const Color _orange700Dark = Color(0xFFFFA266); // == orange300
  static Color get orange700 => _isDark ? _orange700Dark : _orange700Light;

  static const Color orange800 = Color(0xFF8A3900);
  static const Color orange900 = Color(0xFF5C2600);

  // ── Transparent variants ────────────────────────────────────────────────
  static const Color blackTransparent0 = Color(0x00000000);
  static const Color blackTransparent40 = Color(0x66000000);
  static const Color blackTransparent50 = Color(0x80000000);
  static const Color blackTransparent80 = Color(0xCC000000);

  // Hint-tekst kleur (60% opacity). Brightness-aware zodat hint leesbaar
  // blijft op zowel een licht als een donker oppervlak.
  static const Color _grayTransparent50Light = Color(0x99000000);
  static const Color _grayTransparent50Dark = Color(0x99FFFFFF);
  static Color get grayTransparent50 =>
      _isDark ? _grayTransparent50Dark : _grayTransparent50Light;

  // ── Themes ───────────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(TextTheme base) {
    return base
        .apply(fontFamily: 'Manrope')
        .copyWith(
          displayLarge: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          headlineMedium: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          titleLarge: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          bodyLarge: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
          bodyMedium: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
          bodySmall: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: _whiteLight,
      textTheme: _buildTextTheme(base.textTheme),
      colorScheme: base.colorScheme.copyWith(
        primary: orange500,
        onPrimary: _whiteLight,
        surface: _whiteLight,
        onSurface: _blackLight,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: orange500,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          fontFamily: 'Manrope',
          color: _whiteLight,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: _whiteDark,
      canvasColor: _whiteDark,
      cardColor: _whiteDark,
      textTheme: _buildTextTheme(
        base.textTheme,
      ).apply(bodyColor: _blackDark, displayColor: _blackDark),
      iconTheme: const IconThemeData(color: _blackDark),
      dividerColor: _gray100Dark,
      colorScheme: base.colorScheme.copyWith(
        primary: orange500,
        onPrimary: _whiteLight, // tekst op een oranje knop blijft wit
        surface: _whiteDark,
        onSurface: _blackDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _whiteDark,
        foregroundColor: _blackDark,
        surfaceTintColor: _whiteDark,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: orange500,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          fontFamily: 'Manrope',
          color: _whiteLight,
        ),
      ),
    );
  }
}
