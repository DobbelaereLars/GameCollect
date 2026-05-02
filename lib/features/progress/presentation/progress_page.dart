import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

/// Voortgangspagina — binnenkort beschikbaar met uitgebreide spelstatistieken.
class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.orange50,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  LucideIcons.chartBar,
                  size: 40,
                  color: AppTheme.orange500,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Voortgang',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gedetailleerde spelstatistieken en voortgangsgrafieken komen binnenkort beschikbaar.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppTheme.gray500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
