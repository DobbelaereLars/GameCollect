import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/collection_item.dart';
import '../../../discover/domain/rawg_game.dart';

class AddToCollectionSheet extends StatefulWidget {
  final RawgGameDetails game;

  const AddToCollectionSheet({super.key, required this.game});

  static Future<void> show(BuildContext context, RawgGameDetails game) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddToCollectionSheet(game: game),
      ),
    );
  }

  @override
  State<AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<AddToCollectionSheet> {
  int _currentStep = 0;
  final Set<String> _selectedPlatforms = {};
  List<String> _platformsToFormat = [];
  final Map<String, String> _platformFormats = {};

  @override
  void initState() {
    super.initState();
    if (widget.game.platforms.length == 1) {
      final platform = widget.game.platforms.first;
      _selectedPlatforms.add(platform);
      _platformsToFormat = [platform];
      _platformFormats[platform] = 'Fysiek';
      // Skip to format screen if only 1 platform
      _currentStep = 1;
    }
  }

  void _saveToCollection() async {
    final customizedPlatforms = _selectedPlatforms.map((p) {
      final format = _platformFormats[p] ?? 'Fysiek';
      return '$p ($format)';
    }).toList();

    final allUsedFormats = _selectedPlatforms
        .map((p) => _platformFormats[p] ?? 'Fysiek')
        .toSet();
    bool hasPhysical =
        allUsedFormats.contains('Fysiek') ||
        allUsedFormats.contains('Fysiek & Digitaal');
    bool hasDigital =
        allUsedFormats.contains('Digitaal') ||
        allUsedFormats.contains('Fysiek & Digitaal');

    String finalFormat;
    if (hasPhysical && hasDigital) {
      finalFormat = 'Fysiek & Digitaal';
    } else if (hasPhysical) {
      finalFormat = 'Fysiek';
    } else if (hasDigital) {
      finalFormat = 'Digitaal';
    } else {
      finalFormat = 'Fysiek & Digitaal';
    }

    final item = CollectionItem(
      apiId: widget.game.id,
      title: widget.game.title,
      coverUrl: widget.game.coverUrl,
      publisher: widget.game.publishers.isNotEmpty
          ? widget.game.publishers.first
          : null,
      format: finalFormat,
      selectedPlatforms: customizedPlatforms,
      tags: widget.game.tags.take(8).toList(),
      addedAt: DateTime.now(),
    );

    await DatabaseHelper.instance.insertCollectionItem(item);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Toegevoegd aan collectie!')),
        );
    }
  }

  void _nextStep() {
    setState(() {
      if (_currentStep == 0) {
        if (_selectedPlatforms.isEmpty) {
          ScaffoldMessenger.of(context)
            ..removeCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Selecteer minstens één platform')),
            );
          return;
        }
        _platformsToFormat = _selectedPlatforms.toList();
      }

      if (_currentStep >= _platformsToFormat.length) {
        _saveToCollection();
      } else {
        _currentStep++;
      }
    });
  }

  void _previousStep() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  Widget _buildPlatformSelection(TextTheme textTheme) {
    if (widget.game.platforms.isEmpty) {
      return Text(
        'Geen platforms beschikbaar voor deze game.',
        style: textTheme.bodyMedium?.copyWith(color: AppTheme.gray500),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Platform(s)',
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Selecteer de platformen in je bezit',
          style: textTheme.bodySmall?.copyWith(color: AppTheme.gray500),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: widget.game.platforms.map((platform) {
            final isSelected = _selectedPlatforms.contains(platform);
            return FilterChip(
              showCheckmark: false,
              label: Text(platform),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedPlatforms.add(platform);
                  } else {
                    _selectedPlatforms.remove(platform);
                  }
                });
              },
              selectedColor: AppTheme.orange500,
              checkmarkColor: AppTheme.white,
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
          }).toList(),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _selectedPlatforms.isEmpty ? null : _nextStep,
          icon: Icon(
            _platformsToFormat.isNotEmpty &&
                    _currentStep >= _platformsToFormat.length
                ? LucideIcons.save
                : LucideIcons.arrowRight,
            size: 20,
          ),
          label: Text(
            _platformsToFormat.isNotEmpty &&
                    _currentStep >= _platformsToFormat.length
                ? 'Opslaan in collectie'
                : 'Volgende',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.orange500,
            foregroundColor: AppTheme.white,
            disabledBackgroundColor: AppTheme.orange100,
            disabledForegroundColor: AppTheme.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatSelection(TextTheme textTheme) {
    if (_currentStep == 0 || _currentStep > _platformsToFormat.length) {
      return const SizedBox.shrink();
    }

    final platform = _platformsToFormat[_currentStep - 1];
    final selectedFormat = _platformFormats[platform] ?? 'Fysiek';

    final isLastStep = _currentStep == _platformsToFormat.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: AppTheme.black),
              onPressed: _previousStep,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Text(
              'Formaat voor $platform',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 0),
        Padding(
          padding: const EdgeInsets.only(left: 57),
          child: Text(
            'Selecteer de vorm waarin je de game bezit',
            style: textTheme.bodySmall?.copyWith(color: AppTheme.gray500),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: ['Fysiek', 'Digitaal', 'Fysiek & Digitaal'].map((format) {
            final isFormatSelected = selectedFormat == format;
            return ChoiceChip(
              showCheckmark: false,
              label: Text(format),
              selected: isFormatSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _platformFormats[platform] = format;
                  });
                }
              },
              selectedColor: AppTheme.orange500,
              labelStyle: textTheme.bodySmall?.copyWith(
                color: isFormatSelected ? AppTheme.white : AppTheme.black,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppTheme.white,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isFormatSelected
                      ? AppTheme.orange500
                      : AppTheme.orange200,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _nextStep,
          icon: Icon(
            isLastStep ? LucideIcons.save : LucideIcons.arrowRight,
            size: 20,
          ),
          label: Text(
            isLastStep ? 'Opslaan in collectie' : 'Volgende',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.orange500,
            foregroundColor: AppTheme.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Toevoegen aan collectie',
                style: textTheme.titleLarge?.copyWith(
                  color: AppTheme.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, color: AppTheme.black),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _currentStep == 0
                ? _buildPlatformSelection(textTheme)
                : _buildFormatSelection(textTheme),
          ),
        ],
      ),
    );
  }
}
