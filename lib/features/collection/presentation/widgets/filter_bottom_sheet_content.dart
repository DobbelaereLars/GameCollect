import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';

/// Bottom sheet inhoud voor het instellen van collectiefilters (formaat + platform).
///
/// Beheert zijn eigen tijdelijke selectiestatus en geeft het eindresultaat
/// terug via [onApply]. Het wissen van alle actieve filters wordt afgehandeld
/// via [onClearFilters].
class FilterBottomSheetContent extends StatefulWidget {
  const FilterBottomSheetContent({
    super.key,
    required this.availablePlatforms,
    required this.initialFormats,
    required this.initialPlatforms,
    required this.hasActiveFilters,
    required this.onClearFilters,
    required this.onApply,
  });

  final List<String> availablePlatforms;
  final Set<String> initialFormats;
  final Set<String> initialPlatforms;
  final bool hasActiveFilters;

  /// Geroepen als de gebruiker alle filters wist.
  final VoidCallback onClearFilters;

  /// Geroepen met de geselecteerde formaten en platformen bij het toepassen.
  final void Function(Set<String> formats, Set<String> platforms) onApply;

  @override
  State<FilterBottomSheetContent> createState() =>
      _FilterBottomSheetContentState();
}

class _FilterBottomSheetContentState extends State<FilterBottomSheetContent> {
  late Set<String> _formats;
  late Set<String> _platforms;

  @override
  void initState() {
    super.initState();
    _formats = Set.from(widget.initialFormats);
    _platforms = Set.from(widget.initialPlatforms);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: textTheme.titleLarge?.copyWith(
                    color: AppTheme.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.hasActiveFilters)
                      TextButton(
                        onPressed: () {
                          widget.onClearFilters();
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.orange500,
                        ),
                        child: const Text('Filters wissen'),
                      ),
                    IconButton(
                      icon: Icon(LucideIcons.x, color: AppTheme.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Formaat sectie
            Text(
              'Formaat',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 0,
              children: ['Fysiek', 'Digitaal', 'Fysiek & Digitaal'].map((
                format,
              ) {
                final isSelected = _formats.contains(format);
                return _FilterChip(
                  label: format,
                  isSelected: isSelected,
                  onToggle: (selected) => setState(() {
                    if (selected) {
                      _formats.add(format);
                    } else {
                      _formats.remove(format);
                    }
                  }),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Platform sectie
            Text(
              'Platform(s)',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.availablePlatforms.isEmpty)
              Text('Geen platformen gevonden.', style: textTheme.bodySmall)
            else
              Wrap(
                spacing: 8,
                runSpacing: 0,
                children: widget.availablePlatforms.map((platform) {
                  final isSelected = _platforms.contains(platform);
                  return _FilterChip(
                    label: platform,
                    isSelected: isSelected,
                    onToggle: (selected) => setState(() {
                      if (selected) {
                        _platforms.add(platform);
                      } else {
                        _platforms.remove(platform);
                      }
                    }),
                  );
                }).toList(),
              ),

            const SizedBox(height: 24),

            // Toepassen knop
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_formats, _platforms);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orange500,
                  foregroundColor: AppTheme.trueWhite,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Toepassen',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Herbruikbare FilterChip voor formaat- en platformselectie.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onToggle,
  });

  final String label;
  final bool isSelected;
  final void Function(bool) onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FilterChip(
      showCheckmark: false,
      label: Text(label),
      selected: isSelected,
      onSelected: onToggle,
      selectedColor: AppTheme.orange500,
      checkmarkColor: AppTheme.trueWhite,
      labelStyle: textTheme.bodySmall?.copyWith(
        color: isSelected ? AppTheme.white : AppTheme.black,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppTheme.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? AppTheme.orange500 : AppTheme.orange100,
        ),
      ),
    );
  }
}
