import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Base colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Gray scale (from black)
  static const Color gray900 = Color(0xFF1A1A1A); // 90% black
  static const Color gray700 = Color(0xFF4D4D4D); // 60% black
  static const Color gray500 = Color(0xFF808080); // 50% black
  static const Color gray300 = Color(0xFFB3B3B3); // 30% black
  static const Color gray100 = Color(0xFFE6E6E6); // 10% black

  // Glass effect colors
  static const Color glassLight = Color(0xF5FFFFFF); // Very subtle white tint

  // Orange palette (from copilot-instructions.md)
  static const Color orange50 = Color(0xFFFFF4EB);
  static const Color orange100 = Color(0xFFFFE2CC);
  static const Color orange200 = Color(0xFFFFC299);
  static const Color orange300 = Color(0xFFFFA266);
  static const Color orange400 = Color(0xFFFF8A3D);
  static const Color orange500 = Color(0xFFFF6B00); // Primary accent
  static const Color orange600 = Color(0xFFE65F00);
  static const Color orange700 = Color(0xFFB84C00);
  static const Color orange800 = Color(0xFF8A3900);
  static const Color orange900 = Color(0xFF5C2600);

  // Transparent black variants (for overlays/gradients)
  static const Color blackTransparent0 = Color(0x00000000); // Fully transparent
  static const Color blackTransparent40 = Color(0x66000000); // 40% opacity
  static const Color blackTransparent50 = Color(0x80000000); // 50% opacity
  static const Color blackTransparent80 = Color(0xCC000000); // 80% opacity

  // Transparent gray variants
  static const Color grayTransparent50 = Color(
    0x99000000,
  ); // 60% opacity (used for hints)

  static ThemeData get lightTheme {
    final baseTheme = ThemeData.light();

    final textTheme = baseTheme.textTheme
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

    return baseTheme.copyWith(
      scaffoldBackgroundColor: white,
      textTheme: textTheme,
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: orange500,
        onPrimary: white,
        surface: white,
        onSurface: black,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: orange500,
        contentTextStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'Manrope',
          color: white,
        ),
      ),
    );
  }
}
