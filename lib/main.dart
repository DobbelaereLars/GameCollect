import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
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

    final theme = baseTheme.copyWith(
      scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      textTheme: textTheme,
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: const Color(0xFFFF6B00),
        onPrimary: const Color(0xFFFFFFFF),
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF000000),
      ),
    );

    return MaterialApp(
      theme: theme,
      home: const Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}
