import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color orange500 = Color(0xFFFF6B00);

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
    );
  }
}
