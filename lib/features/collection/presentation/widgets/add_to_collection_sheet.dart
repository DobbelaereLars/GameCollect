import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/collection_item.dart';
import '../../../discover/data/rawg_games_api.dart';
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
  final RawgGamesApi _rawgGamesApi = const RawgGamesApi();
  int _currentStep = 0;
  final Set<String> _selectedPlatforms = {};
  List<String> _platformsToFormat = [];
  final Map<String, String> _platformFormats = {};
  bool _isSaving = false;

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

  Future<void> _saveToCollection() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final customizedPlatforms = _selectedPlatforms.map((p) {
        final format = _platformFormats[p] ?? 'Fysiek';
        return '$p ($format)';
      }).toList();

      List<AchievementState> initialStates = const [];
      final rawgApiKey = dotenv.env['RAWG_API_KEY'] ?? '';
      if (rawgApiKey.isNotEmpty) {
        final hasAchievements = await DatabaseHelper.instance
            .hasAchievementsForGame(widget.game.id);
        if (!hasAchievements) {
          final client = http.Client();
          try {
            final achievements = await _rawgGamesApi.fetchGameAchievements(
              client: client,
              apiKey: rawgApiKey,
              id: widget.game.id,
            );
            debugPrint(
              '[GameCollect] Achievements opgehaald voor game ${widget.game.id}: ${achievements.length} stuks',
            );
            await DatabaseHelper.instance.insertAchievementsForGame(
              widget.game.id,
              achievements,
            );
            initialStates = achievements
                .map(
                  (a) => AchievementState(
                    rawgId: a.id,
                    isCompleted: false,
                    isEnabled: true,
                  ),
                )
                .toList(growable: false);
          } catch (e, st) {
            debugPrint('[GameCollect] Achievements ophalen mislukt: $e\n$st');
            initialStates = const [];
          } finally {
            client.close();
          }
        } else {
          final rawRows = await DatabaseHelper.instance
              .getRawAchievementsForGame(widget.game.id);
          initialStates = rawRows
              .map(
                (row) => AchievementState(
                  rawgId: row['rawgId'] as int,
                  isCompleted: false,
                  isEnabled: true,
                ),
              )
              .toList(growable: false);
        }
      } else {
        debugPrint('[GameCollect] RAWG_API_KEY is leeg — achievements overgeslagen.');
      }

      for (final platformWithFormat in customizedPlatforms) {
        final formatMatch =
            RegExp(r'\((.*?)\)$').firstMatch(platformWithFormat);
        final format = formatMatch?.group(1) ?? 'Fysiek & Digitaal';

        final item = CollectionItem(
          apiId: widget.game.id,
          title: widget.game.title,
          coverUrl: widget.game.coverUrl,
          publisher: widget.game.publishers.isNotEmpty
              ? widget.game.publishers.first
              : null,
          format: format,
          selectedPlatforms: [platformWithFormat],
          suggestedTags: widget.game.tags.take(12).toList(),
          selectedSuggestedTags: const [],
          customTags: const [],
          selectedCustomTags: const [],
          notes: '',
          playtimeEntries: const [],
          achievementStates: initialStates,
          addedAt: DateTime.now(),
        );

        await DatabaseHelper.instance.insertCollectionItem(item);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Toegevoegd aan collectie!')),
          );
      }
    } catch (e, st) {
      debugPrint('[GameCollect] Opslaan mislukt: $e\n$st');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Er is iets misgegaan bij het opslaan.')),
          );
      }
    }
  }

  void _nextStep() {
    if (_isSaving) return;
    if (_currentStep == 0) {
      if (_selectedPlatforms.isEmpty) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Selecteer minstens één platform')),
          );
        return;
      }
      setState(() {
        _platformsToFormat = _selectedPlatforms.toList();
        _currentStep++;
      });
      return;
    }

    if (_currentStep >= _platformsToFormat.length) {
      _saveToCollection();
    } else {
      setState(() => _currentStep++);
    }
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
        ElevatedButton(
          onPressed: (_selectedPlatforms.isEmpty || _isSaving) ? null : _nextStep,
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
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.arrowRight, size: 20),
              SizedBox(width: 8),
              Text('Volgende', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
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
        ElevatedButton(
          onPressed: _isSaving ? null : _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.orange500,
            foregroundColor: AppTheme.white,
            disabledBackgroundColor: AppTheme.orange500.withValues(alpha: 0.6),
            disabledForegroundColor: AppTheme.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLastStep && _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLastStep ? LucideIcons.save : LucideIcons.arrowRight,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isLastStep ? 'Opslaan in collectie' : 'Volgende',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_isSaving,
      child: Padding(
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
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
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
      ),
    );
  }
}
