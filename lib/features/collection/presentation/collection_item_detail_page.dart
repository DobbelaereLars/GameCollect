import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/collection_item.dart';
import '../../achievements/data/app_achievement_service.dart';
import '../../discover/data/rawg_games_api.dart';
import '../../discover/presentation/discover_page.dart';
import 'disabled_achievements_page.dart';
import 'disabled_requirements_page.dart';
import 'notes_page.dart';
import 'playtime_page.dart';
import 'widgets/add_platform_sheet.dart';

class CollectionItemDetailPage extends StatefulWidget {
  const CollectionItemDetailPage({
    super.key,
    required this.itemId,
    this.openTagsOnStart = false,
  });

  final int itemId;
  final bool openTagsOnStart;

  @override
  State<CollectionItemDetailPage> createState() =>
      _CollectionItemDetailPageState();
}

class _CollectionItemDetailPageState extends State<CollectionItemDetailPage> {
  static const int _maxActiveTags = 10;
  static const int _maxCustomTagLength = 15;
  static const int _achievementsPerPage = 10;

  CollectionItem? _item;
  bool _isLoading = true;
  bool _hasOpenedTagsOnStart = false;
  List<GameAchievementWithState> _achievements = [];
  // Stable display order — only re-sorted after the delay timer fires
  List<GameAchievementWithState> _displayAchievements = [];

  // Achievement pagination & delayed sort
  int _achievementPage = 0;
  Timer? _sortTimer;

  // Requirements
  List<CustomRequirement> _requirements = [];
  List<CustomRequirement> _displayRequirements = [];
  int _requirementPage = 0;
  Timer? _requirementSortTimer;

  InputDecoration _orangeInputDecoration({
    String? hintText,
    String? labelText,
    bool isDense = true,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      isDense: isDense,
      hintStyle: TextStyle(fontFamily: 'Manrope', color: AppTheme.gray500),
      labelStyle: TextStyle(fontFamily: 'Manrope', color: AppTheme.orange700),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.orange300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.orange300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.orange600, width: 1.5),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  @override
  void dispose() {
    _sortTimer?.cancel();
    _requirementSortTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadItem() async {
    setState(() {
      _isLoading = true;
    });

    var item = await DatabaseHelper.instance.getCollectionItemById(
      widget.itemId,
    );
    if (!mounted) return;

    if (item == null) {
      Navigator.of(context).pop();
      return;
    }

    var achievements = await DatabaseHelper.instance.getAchievementsWithStates(
      item.apiId,
      item.achievementStates,
    );

    // Auto-fetch from RAWG when the game has achievement states (synced from
    // Firebase) but the local game_achievements table has no definitions yet.
    // This happens when a collection item is restored on a new device.
    if (achievements.isEmpty && item.achievementStates.isNotEmpty) {
      final apiKey = dotenv.env['RAWG_API_KEY'] ?? '';
      if (apiKey.isNotEmpty) {
        final client = http.Client();
        try {
          final api = const RawgGamesApi();
          final fetched = await api.fetchGameAchievements(
            client: client,
            apiKey: apiKey,
            id: item.apiId,
          );
          if (fetched.isNotEmpty) {
            await DatabaseHelper.instance.upsertAchievementsForGame(
              item.apiId,
              fetched,
            );
            achievements = await DatabaseHelper.instance
                .getAchievementsWithStates(item.apiId, item.achievementStates);
          }
        } catch (e) {
          debugPrint(
            '[GameCollect] Auto-fetch achievements na sync mislukt: $e',
          );
        } finally {
          client.close();
        }
      }
    }

    // If achievements exist in game_achievements but states aren't tracked yet
    // (e.g. game was added before this feature), initialise them.
    if (achievements.isNotEmpty && item.achievementStates.isEmpty) {
      final newStates = achievements
          .map(
            (a) => AchievementState(
              rawgId: a.rawgId,
              isCompleted: false,
              isEnabled: true,
            ),
          )
          .toList(growable: false);
      final updated = item.copyWith(achievementStates: newStates);
      await DatabaseHelper.instance.updateCollectionItem(updated);
      item = updated;
      achievements = await DatabaseHelper.instance.getAchievementsWithStates(
        item.apiId,
        item.achievementStates,
      );
    }

    if (!mounted) return;
    setState(() {
      _item = item;
      _achievements = achievements;
      _displayAchievements = _sortedByCompletion(achievements);
      _requirements = List<CustomRequirement>.from(item!.requirements);
      _displayRequirements = _sortedRequirementsByCompletion(item.requirements);
      _isLoading = false;
    });

    if (widget.openTagsOnStart && !_hasOpenedTagsOnStart) {
      _hasOpenedTagsOnStart = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showTagsOnboardingSheet();
      });
    }
  }

  Future<void> _persistItem(CollectionItem updated) async {
    await DatabaseHelper.instance.updateCollectionItem(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _item = updated;
    });
  }

  Future<void> _showTagsOnboardingSheet() async {
    final item = _item;
    if (item == null) {
      return;
    }

    int step = 0;
    final selectedSuggestedTags = Set<String>.from(item.selectedSuggestedTags);
    final customTags = List<String>.from(item.customTags);
    final selectedCustomTags = Set<String>.from(item.selectedCustomTags);
    final customTagController = TextEditingController();

    int activeTagCount() {
      return selectedSuggestedTags.length + selectedCustomTags.length;
    }

    bool canAddActiveTag() {
      return activeTagCount() < _maxActiveTags;
    }

    void addCustomTag(void Function(void Function()) setSheetState) {
      final value = customTagController.text.trim();
      if (value.isEmpty) {
        return;
      }

      final existsInSuggested = selectedSuggestedTags.any(
        (tag) => tag.toLowerCase() == value.toLowerCase(),
      );
      final existsInCustom = customTags.any(
        (tag) => tag.toLowerCase() == value.toLowerCase(),
      );
      if (existsInSuggested || existsInCustom) {
        customTagController.clear();
        return;
      }

      if (!canAddActiveTag()) {
        return;
      }

      setSheetState(() {
        customTags.add(value);
        selectedCustomTags.add(value);
        customTagController.clear();
      });
      FocusManager.instance.primaryFocus?.unfocus();
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final hasSuggestedTags = item.suggestedTags.isNotEmpty;
            final sectionTitle = step == 0 ? 'Voorgestelde tags' : 'Eigen tags';
            final sectionMeta = step == 0
                ? 'Kies voorgestelde tags die je actief wil gebruiken. Dit is optioneel.'
                : 'Voeg je eigen tags toe door te typen en op Toevoegen te drukken.';
            final selectedCount = activeTagCount();
            final isTagLimitReached = selectedCount >= _maxActiveTags;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(sheetContext).viewInsets.bottom + 40,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tags toevoegen',
                          style: Theme.of(sheetContext).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.black,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: Icon(LucideIcons.x, color: AppTheme.black),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (step == 1)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              LucideIcons.arrowLeft,
                              color: AppTheme.black,
                            ),
                            onPressed: () {
                              setSheetState(() {
                                step = 0;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            sectionTitle,
                            style: Theme.of(sheetContext).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.black,
                                ),
                          ),
                        ],
                      )
                    else
                      Text(
                        sectionTitle,
                        style: Theme.of(sheetContext).textTheme.bodyLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.black,
                            ),
                      ),
                    const SizedBox(height: 0),
                    Padding(
                      padding: EdgeInsets.only(left: step == 1 ? 57 : 0),
                      child: Text(
                        sectionMeta,
                        style: Theme.of(sheetContext).textTheme.bodySmall
                            ?.copyWith(color: AppTheme.gray500),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.only(left: step == 1 ? 57 : 0),
                      child: Text(
                        'Geselecteerd: $selectedCount/$_maxActiveTags',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: isTagLimitReached
                              ? AppTheme.orange700
                              : AppTheme.gray700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (step == 0) ...[
                      if (!hasSuggestedTags)
                        Text(
                          'Geen voorgestelde tags beschikbaar voor deze game.',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                            color: AppTheme.gray700,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 0,
                          children: item.suggestedTags.map((tag) {
                            final isSelected = selectedSuggestedTags.contains(
                              tag,
                            );
                            return FilterChip(
                              showCheckmark: false,
                              label: Text(tag),
                              selected: isSelected,
                              onSelected: (selected) {
                                setSheetState(() {
                                  if (selected) {
                                    if (!canAddActiveTag()) {
                                      return;
                                    }
                                    selectedSuggestedTags.add(tag);
                                  } else {
                                    selectedSuggestedTags.remove(tag);
                                  }
                                });
                              },
                              selectedColor: AppTheme.orange500,
                              backgroundColor: AppTheme.white,
                              side: BorderSide(
                                color: isSelected
                                    ? AppTheme.orange500
                                    : AppTheme.orange100,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              labelStyle: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppTheme.white
                                    : AppTheme.black,
                              ),
                            );
                          }).toList(),
                        ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customTagController,
                              cursorColor: AppTheme.orange600,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(
                                  _maxCustomTagLength,
                                ),
                              ],
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                color: AppTheme.black,
                              ),
                              decoration:
                                  _orangeInputDecoration(
                                    hintText: 'Typ je eigen tag',
                                  ).copyWith(
                                    suffix:
                                        ValueListenableBuilder<
                                          TextEditingValue
                                        >(
                                          valueListenable: customTagController,
                                          builder: (context, value, child) {
                                            final len = value.text.length;
                                            return Text(
                                              '$len/$_maxCustomTagLength',
                                              style: TextStyle(
                                                fontFamily: 'Manrope',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    len == _maxCustomTagLength
                                                    ? AppTheme.orange700
                                                    : AppTheme.gray500,
                                              ),
                                            );
                                          },
                                        ),
                                  ),
                              onSubmitted: (_) => addCustomTag(setSheetState),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isTagLimitReached
                                  ? null
                                  : () => addCustomTag(setSheetState),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.orange500,
                                foregroundColor: AppTheme.trueWhite,
                                disabledBackgroundColor: AppTheme.orange100,
                                disabledForegroundColor: AppTheme.trueWhite,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Toevoegen'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (customTags.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 0,
                          children: customTags.map((tag) {
                            final isSelected = selectedCustomTags.contains(tag);
                            return InputChip(
                              label: Text(tag),
                              deleteIcon: Icon(
                                LucideIcons.x,
                                size: 16,
                                color: isSelected
                                    ? AppTheme.white
                                    : AppTheme.orange500,
                              ),
                              onPressed: () {
                                setSheetState(() {
                                  if (isSelected) {
                                    selectedCustomTags.remove(tag);
                                  } else {
                                    if (!canAddActiveTag()) {
                                      return;
                                    }
                                    selectedCustomTags.add(tag);
                                  }
                                });
                              },
                              onDeleted: () {
                                setSheetState(() {
                                  customTags.remove(tag);
                                  selectedCustomTags.remove(tag);
                                });
                              },
                              backgroundColor: isSelected
                                  ? AppTheme.orange500
                                  : AppTheme.white,
                              side: BorderSide(
                                color: isSelected
                                    ? AppTheme.orange500
                                    : AppTheme.orange100,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              labelStyle: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                                color: isSelected
                                    ? AppTheme.white
                                    : AppTheme.black,
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: step == 0
                          ? () {
                              setSheetState(() {
                                step = 1;
                              });
                            }
                          : () async {
                              final updated = item.copyWith(
                                selectedSuggestedTags: selectedSuggestedTags
                                    .toList(growable: false),
                                customTags: customTags,
                                selectedCustomTags: selectedCustomTags.toList(
                                  growable: false,
                                ),
                              );
                              await _persistItem(updated);
                              if (!mounted) {
                                return;
                              }
                              if (!sheetContext.mounted) {
                                return;
                              }
                              Navigator.of(sheetContext).pop();
                            },
                      icon: Icon(
                        step == 0 ? LucideIcons.arrowRight : LucideIcons.save,
                        size: 20,
                      ),
                      label: Text(
                        step == 0 ? 'Volgende' : 'Opslaan',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.orange500,
                        foregroundColor: AppTheme.trueWhite,
                        disabledBackgroundColor: AppTheme.orange100,
                        disabledForegroundColor: AppTheme.trueWhite,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Reschedule the delayed sort — resets the timer on every toggle so rapid
  // tapping doesn't cause premature reordering.
  void _scheduleSortDelay() {
    _sortTimer?.cancel();
    _sortTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _displayAchievements = _sortedByCompletion(_achievements);
        });
      }
    });
  }

  List<GameAchievementWithState> _sortedByCompletion(
    List<GameAchievementWithState> src,
  ) {
    return [
      ...src.where((a) => !a.isCompleted),
      ...src.where((a) => a.isCompleted),
    ];
  }

  List<CustomRequirement> _sortedRequirementsByCompletion(
    List<CustomRequirement> src,
  ) {
    return [
      ...src.where((r) => !r.isCompleted),
      ...src.where((r) => r.isCompleted),
    ];
  }

  void _scheduleRequirementSortDelay() {
    _requirementSortTimer?.cancel();
    _requirementSortTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _displayRequirements = _sortedRequirementsByCompletion(_requirements);
        });
      }
    });
  }

  Future<void> _toggleRequirementCompleted(String id, bool value) async {
    final item = _item;
    if (item == null) return;
    final updated = item.requirements
        .map((r) => r.id == id ? r.copyWith(isCompleted: value) : r)
        .toList(growable: false);
    await _persistItem(item.copyWith(requirements: updated));
    if (!mounted) return;
    setState(() {
      _requirements = _requirements
          .map((r) => r.id == id ? r.copyWith(isCompleted: value) : r)
          .toList(growable: false);
      _displayRequirements = _displayRequirements
          .map((r) => r.id == id ? r.copyWith(isCompleted: value) : r)
          .toList(growable: false);
    });
    _scheduleRequirementSortDelay();
  }

  Future<void> _toggleRequirementEnabled(String id, bool enabled) async {
    final item = _item;
    if (item == null) return;
    final updated = item.requirements
        .map((r) => r.id == id ? r.copyWith(isEnabled: enabled) : r)
        .toList(growable: false);
    await _persistItem(item.copyWith(requirements: updated));
    if (!mounted) return;
    setState(() {
      _requirements = _requirements
          .map((r) => r.id == id ? r.copyWith(isEnabled: enabled) : r)
          .toList(growable: false);
      _displayRequirements = _sortedRequirementsByCompletion(_requirements);
    });
  }

  Future<void> _deleteRequirement(String id) async {
    final item = _item;
    if (item == null) return;
    final updated = item.requirements
        .where((r) => r.id != id)
        .toList(growable: false);
    await _persistItem(item.copyWith(requirements: updated));
    if (!mounted) return;
    setState(() {
      _requirements = _requirements
          .where((r) => r.id != id)
          .toList(growable: false);
      _displayRequirements = _sortedRequirementsByCompletion(_requirements);
    });
  }

  Future<void> _toggleAchievementCompleted(int rawgId, bool value) async {
    final item = _item;
    if (item == null) return;

    final baseStates = item.achievementStates.isNotEmpty
        ? item.achievementStates
        : _achievements
              .map(
                (a) => AchievementState(
                  rawgId: a.rawgId,
                  isCompleted: false,
                  isEnabled: a.isEnabled,
                ),
              )
              .toList();

    final updatedStates = baseStates
        .map((s) => s.rawgId == rawgId ? s.copyWith(isCompleted: value) : s)
        .toList(growable: false);

    await _persistItem(item.copyWith(achievementStates: updatedStates));
    if (!mounted) return;
    // Update the completion state immediately — sorting happens after the delay
    setState(() {
      _achievements = _achievements
          .map((a) => a.rawgId == rawgId ? a.copyWith(isCompleted: value) : a)
          .toList(growable: false);
      // Mirror the change in displayAchievements without resorting yet
      _displayAchievements = _displayAchievements
          .map((a) => a.rawgId == rawgId ? a.copyWith(isCompleted: value) : a)
          .toList(growable: false);
    });
    _scheduleSortDelay();
  }

  Future<void> _toggleAchievementEnabled(int rawgId, bool enabled) async {
    final item = _item;
    if (item == null) return;

    final baseStates = item.achievementStates.isNotEmpty
        ? item.achievementStates
        : _achievements
              .map(
                (a) => AchievementState(
                  rawgId: a.rawgId,
                  isCompleted: a.isCompleted,
                  isEnabled: true,
                ),
              )
              .toList();

    final updatedStates = baseStates
        .map((s) => s.rawgId == rawgId ? s.copyWith(isEnabled: enabled) : s)
        .toList(growable: false);

    await _persistItem(item.copyWith(achievementStates: updatedStates));
    if (!mounted) return;
    setState(() {
      _achievements = _achievements
          .map((a) => a.rawgId == rawgId ? a.copyWith(isEnabled: enabled) : a)
          .toList(growable: false);
      _displayAchievements = _sortedByCompletion(_achievements);
    });
  }

  void _showAchievementModal(GameAchievementWithState achievement) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (achievement.imageUrl != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        achievement.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.orange50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.trophy,
                            size: 36,
                            color: AppTheme.orange300,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.orange50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.trophy,
                        size: 36,
                        color: AppTheme.orange300,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  achievement.name,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: AppTheme.black,
                  ),
                ),
                if (achievement.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: AppTheme.gray700,
                    ),
                  ),
                ],
                if (achievement.percent != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.users,
                        size: 14,
                        color: AppTheme.gray500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${achievement.percent!.toStringAsFixed(1)}% van spelers behaald',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(foregroundColor: AppTheme.gray700),
              child: const Text('Sluiten'),
            ),
          ],
        );
      },
    );
  }

  void _showRequirementModal(CustomRequirement requirement) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (requirement.title?.isNotEmpty == true) ...[
                  Text(
                    requirement.title!,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: AppTheme.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    requirement.description,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: AppTheme.gray700,
                    ),
                  ),
                ] else
                  Text(
                    requirement.description,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: AppTheme.gray700,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(foregroundColor: AppTheme.gray700),
              child: const Text('Sluiten'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteRequirementConfirmSheet(String id) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vereiste verwijderen?',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: Icon(LucideIcons.x, color: AppTheme.black),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Deze vereiste wordt permanent verwijderd uit je collectie.',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: AppTheme.gray700,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await _deleteRequirement(id);
                },
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text(
                  'Verwijderen',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.orange500,
                  side: const BorderSide(color: AppTheme.orange500),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddRequirementSheet() async {
    final item = _item;
    if (item == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddRequirementSheetContent(
        onSave: (title, description) async {
          final newReq = CustomRequirement(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: title.isEmpty ? null : title,
            description: description,
            isCompleted: false,
            isEnabled: true,
          );
          final updatedReqs = [...item.requirements, newReq];
          await _persistItem(item.copyWith(requirements: updatedReqs));
          if (!mounted) return;
          setState(() {
            _requirements = List<CustomRequirement>.from(updatedReqs);
            _displayRequirements = _sortedRequirementsByCompletion(
              _requirements,
            );
          });
          ScaffoldMessenger.of(context)
            ..removeCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Vereiste toegevoegd.')),
            );
        },
      ),
    );
  }

  String _formatMinutes(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) {
      return '$minutes min';
    }
    return '${hours}u ${minutes}m';
  }

  Future<void> _shareGameProgress(CollectionItem item) async {
    final progress = item.isManuallyCompleted
        ? '100%'
        : '${(item.progressRatio * 100).round()}%';
    final playtime = item.totalPlaytimeMinutes == 0
        ? 'Nog niet bijgehouden'
        : _formatMinutes(item.totalPlaytimeMinutes);
    final platform = item.selectedPlatforms.isNotEmpty
        ? item.selectedPlatforms.first.replaceAll(RegExp(r'\s*\(.*\)$'), '')
        : '';
    final platformLine = platform.isNotEmpty ? '\nPlatform: $platform' : '';

    final text =
        '🎮 ${item.title}$platformLine\n\nVoortgang: $progress\nSpeelduur: $playtime\n\nGedeeld via GameCollect';

    try {
      await SharePlus.instance.share(ShareParams(text: text));
      final allItems = await DatabaseHelper.instance.getCollectionItems();
      await AppAchievementService.instance.recordShareEvent(allItems);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.orange500),
        ),
      );
    }

    final item = _item;
    if (item == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.black,
        surfaceTintColor: AppTheme.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Delen',
            icon: const Icon(
              LucideIcons.share2,
              size: 20,
              color: AppTheme.orange500,
            ),
            onPressed: () async => _shareGameProgress(item),
          ),
          IconButton(
            tooltip: 'Instellingen',
            icon: SizedBox(
              width: 32,
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(
                    LucideIcons.settings,
                    size: 20,
                    color: AppTheme.orange500,
                  ),
                  if (item.isManuallyCompleted)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.orange500,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '100%',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.trueWhite,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            onPressed: () => _openSettingsPage(item),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 170),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(item),
                    if (_achievements.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Divider(height: 1, thickness: 1, color: AppTheme.gray100),
                      const SizedBox(height: 24),
                      _buildAchievementsSection(),
                    ],
                    const SizedBox(height: 24),
                    Divider(height: 1, thickness: 1, color: AppTheme.gray100),
                    const SizedBox(height: 24),
                    _buildRequirementsSection(),
                    const SizedBox(height: 24),
                    Divider(height: 1, thickness: 1, color: AppTheme.gray100),
                    const SizedBox(height: 24),
                    _buildPlaytimeSummaryTile(item),
                    const SizedBox(height: 8),
                    _buildDiscoverTile(item),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Container(
              decoration: BoxDecoration(
                // In light mode wit met schaduw; in dark mode iets lichtere
                // surface (#2A2A2A) zodat de bol-vorm zichtbaar blijft
                // tegen de #121212 scaffold.
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.gray100
                    : AppTheme.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    final current = _item;
                    if (current?.id == null) return;
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => NotesPage(
                          itemId: current!.id!,
                          initialNotes: current.notes,
                        ),
                      ),
                    );
                    final refreshed = await DatabaseHelper.instance
                        .getCollectionItemById(widget.itemId);
                    if (mounted && refreshed != null) {
                      setState(() => _item = refreshed);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Icon(
                      LucideIcons.pencilLine,
                      size: 22,
                      color: AppTheme.orange500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(CollectionItem item) {
    final tagActionLabel = item.activeTags.isEmpty
        ? 'Tags toevoegen'
        : 'Tags bewerken';
    final primaryPlatformWithFormat = item.selectedPlatforms.isNotEmpty
        ? item.selectedPlatforms.first
        : '';
    final platformName = _extractPlatformName(primaryPlatformWithFormat);
    final formatName = _extractFormatName(
      primaryPlatformWithFormat,
      fallback: item.format,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                item.customCoverPath != null
                    ? Image.file(
                        File(item.customCoverPath!),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildCoverPlaceholder(),
                      )
                    : (item.coverUrl != null
                          ? Image.network(
                              item.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildCoverPlaceholder(),
                            )
                          : _buildCoverPlaceholder()),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCoverBadge(
                        icon: LucideIcons.gamepad2,
                        text: platformName,
                      ),
                      const SizedBox(height: 6),
                      _buildCoverBadge(
                        icon: _formatIconFor(formatName),
                        text: formatName,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          item.title,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppTheme.black,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...item.activeTags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.orange100),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: AppTheme.black,
                  ),
                ),
              );
            }),
            TextButton(
              onPressed: _showTagsOnboardingSheet,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.orange500,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(tagActionLabel),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildHeaderMetaRow(
          icon: LucideIcons.clock3,
          text: 'Speelduur: ${_formatMinutes(item.totalPlaytimeMinutes)}',
        ),
        const SizedBox(height: 6),
        if (item.publisher != null && item.publisher!.isNotEmpty)
          _buildHeaderMetaRow(
            icon: LucideIcons.building,
            text: item.publisher!,
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: item.progressRatio,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: AppTheme.progressTrack,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.orange500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(item.progressRatio * 100).round()}%',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: AppTheme.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderMetaRow({
    required IconData icon,
    required String text,
    Color? textColor,
  }) {
    final color = textColor ?? AppTheme.gray500;
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.gray500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  String _extractPlatformName(String platformWithFormat) {
    if (platformWithFormat.isEmpty) {
      return 'Onbekend platform';
    }
    final match = RegExp(
      r'^(.*?)(?:\s*\([^)]*\))?$',
    ).firstMatch(platformWithFormat);
    return match?.group(1)?.trim() ?? platformWithFormat;
  }

  Future<void> _openSettingsPage(CollectionItem item) async {
    final primaryPlatformWithFormat = item.selectedPlatforms.isNotEmpty
        ? item.selectedPlatforms.first
        : '';
    final platformName = _extractPlatformName(primaryPlatformWithFormat);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _GameSettingsPage(
          item: item,
          platformName: platformName,
          platformWithFormat: primaryPlatformWithFormat,
          onItemChanged: (updated) {
            if (mounted) setState(() => _item = updated);
          },
          onDeleted: () {
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
      ),
    );
    final refreshed = await DatabaseHelper.instance.getCollectionItemById(
      widget.itemId,
    );
    if (mounted && refreshed != null) {
      setState(() => _item = refreshed);
    }
  }

  String _extractFormatName(String platformWithFormat, {String? fallback}) {
    final match = RegExp(r'\((.*?)\)$').firstMatch(platformWithFormat);
    final value = match?.group(1)?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
    return (fallback == null || fallback.isEmpty)
        ? 'Fysiek & Digitaal'
        : fallback;
  }

  IconData _formatIconFor(String formatName) {
    if (formatName == 'Fysiek') {
      return LucideIcons.disc;
    }
    if (formatName == 'Digitaal') {
      return LucideIcons.download;
    }
    return LucideIcons.layers;
  }

  Widget _buildCoverBadge({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.orange50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.orange500),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: AppTheme.orange700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      color: AppTheme.orange50,
      child: Center(
        child: Icon(LucideIcons.gamepad2, color: AppTheme.black, size: 30),
      ),
    );
  }

  Widget _buildPlaytimeSummaryTile(CollectionItem item) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => PlaytimePage(
              itemId: item.id!,
              gameTitle: item.title,
              initialEntries: item.playtimeEntries,
            ),
          ),
        );
        final refreshed = await DatabaseHelper.instance.getCollectionItemById(
          widget.itemId,
        );
        if (mounted && refreshed != null) {
          setState(() => _item = refreshed);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.white,
          border: Border.all(color: AppTheme.gray100),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.orange50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.clock,
                size: 18,
                color: AppTheme.orange600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Speelduur',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.black,
                    ),
                  ),
                  Text(
                    item.totalPlaytimeMinutes == 0
                        ? 'Nog geen speelduur geregistreerd'
                        : _formatMinutes(item.totalPlaytimeMinutes),
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: item.totalPlaytimeMinutes == 0
                          ? AppTheme.gray300
                          : AppTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: AppTheme.gray300),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverTile(CollectionItem item) {
    return GestureDetector(
      onTap: () {
        // Cycle through null so the same game can be requested multiple times
        DiscoverPage.gameDetailRequest.value = null;
        DiscoverPage.gameDetailRequest.value = (
          gameId: item.apiId,
          fallbackTitle: item.title,
          fallbackCoverUrl: item.coverUrl,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.white,
          border: Border.all(color: AppTheme.gray100),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.orange50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.search,
                size: 18,
                color: AppTheme.orange600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bekijk in Ontdekken',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.black,
                    ),
                  ),
                  Text(
                    'Bekijk de gamepagina met details.',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: AppTheme.gray300),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsSection() {
    // No achievements -> hide entire section
    if (_achievements.isEmpty) return const SizedBox.shrink();

    final enabled = _displayAchievements.where((a) => a.isEnabled).toList();
    final disabled = _achievements.where((a) => !a.isEnabled).toList();
    final completedCount = enabled.where((a) => a.isCompleted).length;
    final allDone = enabled.isNotEmpty && completedCount == enabled.length;

    final totalPages = max(1, (enabled.length / _achievementsPerPage).ceil());
    final safePage = _achievementPage.clamp(0, totalPages - 1);
    final pageStart = safePage * _achievementsPerPage;
    final pageEnd = min(pageStart + _achievementsPerPage, enabled.length);
    final pageItems = enabled.sublist(pageStart, pageEnd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Expanded(
              child: Text(
                'Achievements',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppTheme.black,
                ),
              ),
            ),
            // Score — oranje als alles afgevinkt
            Text(
              '$completedCount/${enabled.length}',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: allDone ? AppTheme.orange500 : AppTheme.gray500,
              ),
            ),
            const SizedBox(width: 16),
            // Eye icon -- zelfde grootte als score, oranje
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DisabledAchievementsPage(
                    initialAchievements: disabled,
                    onToggleCompleted: _toggleAchievementCompleted,
                    onToggleEnabled: _toggleAchievementEnabled,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.eyeOff,
                    size: 12,
                    color: AppTheme.orange500,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '(${disabled.length})',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: AppTheme.orange500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Paginated enabled achievements
        ...pageItems.map((a) => _buildAchievementTile(a)),

        // Pagination controls -- fixed-width counter prevents button drift
        if (totalPages > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPageButton(
                icon: LucideIcons.chevronLeft,
                enabled: safePage > 0,
                onTap: () => setState(() => _achievementPage = safePage - 1),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 64,
                child: Text(
                  '${safePage + 1} / $totalPages',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildPageButton(
                icon: LucideIcons.chevronRight,
                enabled: safePage < totalPages - 1,
                onTap: () => setState(() => _achievementPage = safePage + 1),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPageButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.orange50 : AppTheme.gray100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? AppTheme.orange200 : AppTheme.gray100,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppTheme.orange700 : AppTheme.gray300,
        ),
      ),
    );
  }

  Widget _buildAchievementTile(GameAchievementWithState achievement) {
    final isDisabled = !achievement.isEnabled;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Checkbox(
              value: achievement.isCompleted,
              onChanged: isDisabled
                  ? null
                  : (value) => _toggleAchievementCompleted(
                      achievement.rawgId,
                      value ?? false,
                    ),
              activeColor: AppTheme.orange500,
              side: BorderSide(
                color: isDisabled ? AppTheme.gray300 : AppTheme.gray300,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => _showAchievementModal(achievement),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: achievement.imageUrl != null
                          ? Image.network(
                              achievement.imageUrl!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildAchievementImagePlaceholder(),
                            )
                          : _buildAchievementImagePlaceholder(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        achievement.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                          color: isDisabled ? AppTheme.gray300 : AppTheme.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _toggleAchievementEnabled(
              achievement.rawgId,
              !achievement.isEnabled,
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                LucideIcons.eyeOff,
                size: 18,
                color: isDisabled ? AppTheme.orange400 : AppTheme.gray300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementImagePlaceholder() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.orange50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        LucideIcons.trophy,
        size: 18,
        color: AppTheme.orange300,
      ),
    );
  }

  Widget _buildRequirementsSection() {
    final enabled = _displayRequirements.where((r) => r.isEnabled).toList();
    final disabled = _requirements.where((r) => !r.isEnabled).toList();
    final completedCount = enabled.where((r) => r.isCompleted).length;
    final allDone = enabled.isNotEmpty && completedCount == enabled.length;

    final totalPages = max(1, (enabled.length / _achievementsPerPage).ceil());
    final safePage = _requirementPage.clamp(0, totalPages - 1);
    final pageStart = safePage * _achievementsPerPage;
    final pageEnd = min(pageStart + _achievementsPerPage, enabled.length);
    final pageItems = enabled.isEmpty
        ? <CustomRequirement>[]
        : enabled.sublist(pageStart, pageEnd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Vereisten',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppTheme.black,
                ),
              ),
            ),
            GestureDetector(
              onTap: _showAddRequirementSheet,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  LucideIcons.plus,
                  size: 18,
                  color: AppTheme.orange500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$completedCount/${enabled.length}',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: allDone && enabled.isNotEmpty
                    ? AppTheme.orange500
                    : AppTheme.gray500,
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DisabledRequirementsPage(
                    initialRequirements: disabled,
                    onToggleCompleted: _toggleRequirementCompleted,
                    onToggleEnabled: _toggleRequirementEnabled,
                    onDelete: _deleteRequirement,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.eyeOff,
                    size: 12,
                    color: AppTheme.orange500,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '(${disabled.length})',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: AppTheme.orange500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (enabled.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Nog geen vereisten. Tik op + om er een toe te voegen.',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: AppTheme.gray500,
              ),
            ),
          )
        else
          ...pageItems.map((r) => _buildRequirementTile(r)),
        if (totalPages > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPageButton(
                icon: LucideIcons.chevronLeft,
                enabled: safePage > 0,
                onTap: () => setState(() => _requirementPage = safePage - 1),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 64,
                child: Text(
                  '${safePage + 1} / $totalPages',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildPageButton(
                icon: LucideIcons.chevronRight,
                enabled: safePage < totalPages - 1,
                onTap: () => setState(() => _requirementPage = safePage + 1),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRequirementTile(CustomRequirement requirement) {
    final isDisabled = !requirement.isEnabled;
    final displayText = requirement.title?.isNotEmpty == true
        ? requirement.title!
        : requirement.description;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Checkbox(
              value: requirement.isCompleted,
              onChanged: isDisabled
                  ? null
                  : (value) => _toggleRequirementCompleted(
                      requirement.id,
                      value ?? false,
                    ),
              activeColor: AppTheme.orange500,
              side: BorderSide(color: AppTheme.gray300),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => _showRequirementModal(requirement),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text(
                  displayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                    color: isDisabled ? AppTheme.gray300 : AppTheme.black,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _toggleRequirementEnabled(
              requirement.id,
              !requirement.isEnabled,
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                LucideIcons.eyeOff,
                size: 18,
                color: isDisabled ? AppTheme.orange400 : AppTheme.gray300,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _showDeleteRequirementConfirmSheet(requirement.id),
            child: Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                LucideIcons.trash2,
                size: 18,
                color: AppTheme.gray500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add-requirement sheet ────────────────────────────────────────────────────

class _AddRequirementSheetContent extends StatefulWidget {
  const _AddRequirementSheetContent({required this.onSave});

  final Future<void> Function(String title, String description) onSave;

  @override
  State<_AddRequirementSheetContent> createState() =>
      _AddRequirementSheetContentState();
}

class _AddRequirementSheetContentState
    extends State<_AddRequirementSheetContent> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _descFocusNode = FocusNode();
  bool _descFocused = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _descFocusNode.addListener(_onDescFocusChange);
  }

  void _onDescFocusChange() {
    if (mounted) setState(() => _descFocused = _descFocusNode.hasFocus);
  }

  @override
  void dispose() {
    _descFocusNode.removeListener(_onDescFocusChange);
    _titleController.dispose();
    _descriptionController.dispose();
    _descFocusNode.dispose();
    super.dispose();
  }

  InputDecoration _orangeDecoration({
    required String labelText,
    bool isDense = true,
  }) {
    return InputDecoration(
      labelText: labelText,
      isDense: isDense,
      labelStyle: TextStyle(fontFamily: 'Manrope', color: AppTheme.orange700),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.orange300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.orange300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.orange600, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 40,
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Vereiste toevoegen',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(LucideIcons.x, color: AppTheme.black),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              cursorColor: AppTheme.orange600,
              inputFormatters: [LengthLimitingTextInputFormatter(30)],
              style: TextStyle(fontFamily: 'Manrope', color: AppTheme.black),
              decoration:
                  _orangeDecoration(
                    labelText: 'Titel (optioneel)',
                    isDense: true,
                  ).copyWith(
                    suffix: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _titleController,
                      builder: (_, v, __) => Text(
                        '${v.text.length}/30',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          color: v.text.length == 30
                              ? AppTheme.orange700
                              : AppTheme.gray500,
                        ),
                      ),
                    ),
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              focusNode: _descFocusNode,
              cursorColor: AppTheme.orange600,
              inputFormatters: [LengthLimitingTextInputFormatter(250)],
              maxLines: 4,
              style: TextStyle(fontFamily: 'Manrope', color: AppTheme.black),
              decoration:
                  _orangeDecoration(
                    labelText: 'Beschrijving',
                    isDense: true,
                  ).copyWith(
                    alignLabelWithHint: true,
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    suffix: _descFocused
                        ? ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _descriptionController,
                            builder: (_, v, __) => Text(
                              '${v.text.length}/250',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 11,
                                color: v.text.length == 250
                                    ? AppTheme.orange700
                                    : AppTheme.gray500,
                              ),
                            ),
                          )
                        : null,
                  ),
            ),
            const SizedBox(height: 24),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _descriptionController,
              builder: (_, descValue, __) {
                final canSave = !_isSaving && descValue.text.trim().isNotEmpty;
                return ElevatedButton.icon(
                  onPressed: canSave
                      ? () async {
                          setState(() => _isSaving = true);
                          await widget.onSave(
                            _titleController.text.trim(),
                            _descriptionController.text.trim(),
                          );
                          if (!mounted) return;
                          Navigator.of(context).pop();
                        }
                      : null,
                  icon: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppTheme.trueWhite,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(LucideIcons.save, size: 18),
                  label: const Text(
                    'Opslaan',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange500,
                    foregroundColor: AppTheme.trueWhite,
                    disabledBackgroundColor: AppTheme.orange100,
                    disabledForegroundColor: AppTheme.trueWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Game Settings Page ───────────────────────────────────────────────────────

class _GameSettingsPage extends StatefulWidget {
  const _GameSettingsPage({
    required this.item,
    required this.platformName,
    required this.platformWithFormat,
    this.onItemChanged,
    this.onDeleted,
  });

  final CollectionItem item;
  final String platformName;
  final String platformWithFormat;
  final void Function(CollectionItem)? onItemChanged;
  final void Function()? onDeleted;

  @override
  State<_GameSettingsPage> createState() => _GameSettingsPageState();
}

class _GameSettingsPageState extends State<_GameSettingsPage> {
  static const List<String> _formatOptions = [
    'Fysiek',
    'Digitaal',
    'Fysiek & Digitaal',
  ];

  late bool _isManuallyCompleted;
  late String? _customCoverPath;
  String _currentPlatformWithFormat = '';
  bool _hasMultiplePlatforms = false;
  List<String> _availablePlatforms = [];
  Set<String> _alreadyAddedPlatformNames = {};
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _isManuallyCompleted = widget.item.isManuallyCompleted;
    _customCoverPath = widget.item.customCoverPath;
    _currentPlatformWithFormat = widget.platformWithFormat;
    _loadPlatformCount();
  }

  String get _currentFormat {
    final match = RegExp(
      r'\(([^)]*)\)\s*$',
    ).firstMatch(_currentPlatformWithFormat);
    final raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) return 'Fysiek & Digitaal';
    // Normalize legacy value.
    if (raw == 'Allebei') return 'Fysiek & Digitaal';
    return raw;
  }

  Future<void> _loadPlatformCount() async {
    final count = await DatabaseHelper.instance.countCollectionItemsByApiId(
      widget.item.apiId,
    );
    final allItems = await DatabaseHelper.instance.getCollectionItemsByApiId(
      widget.item.apiId,
    );
    final usedNames = <String>{};
    for (final it in allItems) {
      for (final p in it.selectedPlatforms) {
        final name = _platformNameFrom(p);
        if (name.isNotEmpty) usedNames.add(name);
      }
    }
    if (mounted) {
      setState(() {
        _hasMultiplePlatforms = count > 1;
        _availablePlatforms = [...widget.item.availablePlatforms];
        _alreadyAddedPlatformNames = usedNames;
      });
    }
  }

  static String _platformNameFrom(String platformWithFormat) {
    if (platformWithFormat.isEmpty) return '';
    final match = RegExp(
      r'^(.*?)(?:\s*\([^)]*\))?$',
    ).firstMatch(platformWithFormat);
    return match?.group(1)?.trim() ?? platformWithFormat;
  }

  CollectionItem get _updatedItem => widget.item.copyWith(
    isManuallyCompleted: _isManuallyCompleted,
    customCoverPath: _customCoverPath,
    clearCustomCoverPath: _customCoverPath == null,
  );

  Future<void> _save() async {
    final updated = _updatedItem;
    await DatabaseHelper.instance.updateCollectionItem(updated);
    widget.onItemChanged?.call(updated);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _customCoverPath = picked.path);
    await _save();
  }

  Future<void> _removeCover() async {
    setState(() => _customCoverPath = null);
    await _save();
  }

  Future<void> _showRestoreCoverSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Afbeelding herstellen?',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: Icon(LucideIcons.x, color: AppTheme.black),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Je eigen afbeelding wordt verwijderd en de standaard omslagafbeelding wordt hersteld.',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: AppTheme.gray700,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await _removeCover();
                },
                icon: const Icon(LucideIcons.refreshCcw, size: 18),
                label: const Text(
                  'Standaard afbeelding herstellen',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.orange500,
                  side: const BorderSide(color: AppTheme.orange500),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleCompleted(bool value) async {
    setState(() => _isManuallyCompleted = value);
    await _save();
  }

  Future<void> _changeFormat(String newFormat) async {
    if (newFormat == _currentFormat) return;
    final newPlatformWithFormat = '${widget.platformName} ($newFormat)';
    final updatedPlatforms = widget.item.selectedPlatforms.map((p) {
      return p == _currentPlatformWithFormat ? newPlatformWithFormat : p;
    }).toList();
    final updated = widget.item.copyWith(
      selectedPlatforms: updatedPlatforms,
      format: newFormat,
    );
    await DatabaseHelper.instance.updateCollectionItem(updated);
    if (!mounted) return;
    setState(() {
      _currentPlatformWithFormat = newPlatformWithFormat;
    });
    widget.onItemChanged?.call(updated);
  }

  Future<void> _showFormatSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final current = _currentFormat;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Formaat aanpassen',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: Icon(LucideIcons.x, color: AppTheme.black),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Selecteer de vorm waarin je deze game bezit op '
                '${widget.platformName}.',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: AppTheme.gray700,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _formatOptions.map((format) {
                  final isSelected = current == format;
                  return ChoiceChip(
                    showCheckmark: false,
                    label: Text(format),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        Navigator.of(sheetContext).pop(format);
                      }
                    },
                    selectedColor: AppTheme.orange500,
                    labelStyle: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppTheme.white : AppTheme.black,
                    ),
                    backgroundColor: AppTheme.white,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.orange500
                            : AppTheme.orange200,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      await _changeFormat(selected);
    }
  }

  Widget _buildFormatRow() {
    return InkWell(
      onTap: _showFormatSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            const Icon(LucideIcons.disc3, size: 18, color: AppTheme.orange500),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Formaat',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.black,
                ),
              ),
            ),
            Text(
              _currentFormat,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.gray700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 18, color: AppTheme.gray500),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.black,
        surfaceTintColor: AppTheme.white,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Instellingen',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCoverSection(),
              const SizedBox(height: 24),
              Divider(height: 1, thickness: 1, color: AppTheme.gray100),
              _buildCompletedRow(),
              Divider(height: 1, thickness: 1, color: AppTheme.gray100),
              _buildFormatRow(),
              Divider(height: 1, thickness: 1, color: AppTheme.gray100),
              if (_availablePlatforms
                  .where((p) => !_alreadyAddedPlatformNames.contains(p))
                  .isNotEmpty) ...[
                _buildAddPlatformRow(),
                Divider(height: 1, thickness: 1, color: AppTheme.gray100),
              ],
              _buildRefreshDataRow(),
              Divider(height: 1, thickness: 1, color: AppTheme.gray100),
              _buildDeleteFromPlatformRow(),
              Divider(height: 1, thickness: 1, color: AppTheme.gray100),
              if (_hasMultiplePlatforms) ...[
                _buildDeleteFromAllRow(),
                Divider(height: 1, thickness: 1, color: AppTheme.gray100),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverSection() {
    late Widget coverWidget;
    if (_customCoverPath != null) {
      coverWidget = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(_customCoverPath!),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _buildCoverFallback(),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xAA000000)],
                    ),
                  ),
                  child: TextButton.icon(
                    onPressed: _showRestoreCoverSheet,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.trueWhite,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    ),
                    icon: const Icon(LucideIcons.refreshCcw, size: 16),
                    label: const Text(
                      'Standaard afbeelding herstellen',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (widget.item.coverUrl != null) {
      coverWidget = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            widget.item.coverUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildCoverFallback(),
          ),
        ),
      );
    } else {
      coverWidget = _buildCoverFallback(withRadius: true);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        coverWidget,
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickImage,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.orange500,
            side: const BorderSide(color: AppTheme.orange500),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(LucideIcons.imagePlus, size: 18),
          label: const Text(
            'Kies uit galerij',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverFallback({bool withRadius = false}) {
    Widget child = Container(
      color: AppTheme.orange50,
      child: const Center(
        child: Icon(LucideIcons.gamepad2, size: 40, color: AppTheme.orange300),
      ),
    );
    if (withRadius) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(aspectRatio: 16 / 9, child: child),
      );
    }
    return child;
  }

  Widget _buildCompletedRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '100% voltooid',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.black,
              ),
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.all(AppTheme.white),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected)
                      ? AppTheme.orange500
                      : AppTheme.orange100;
                }),
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                thumbIcon: WidgetStateProperty.all(
                  const Icon(Icons.circle, color: Colors.transparent, size: 1),
                ),
              ),
            ),
            child: Switch(
              value: _isManuallyCompleted,
              onChanged: _toggleCompleted,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteFromPlatformSheet() async {
    final sameGameCount = await DatabaseHelper.instance
        .countCollectionItemsByApiId(widget.item.apiId);
    final isLastPlatform = sameGameCount <= 1;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${widget.item.title} verwijderen?',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: Icon(LucideIcons.x, color: AppTheme.black),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isLastPlatform
                    ? 'De game wordt volledig verwijderd uit je collectie. Al je voortgang, speelduur, achievements en instellingen gaan permanent verloren.'
                    : 'De game wordt verwijderd van ${widget.platformName}. Al je voortgang, speelduur en instellingen voor dit platform gaan permanent verloren.',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: AppTheme.gray700,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  if (widget.item.id != null) {
                    final updatedPlatforms = List<String>.from(
                      widget.item.selectedPlatforms,
                    )..remove(_currentPlatformWithFormat);
                    if (updatedPlatforms.isEmpty) {
                      await DatabaseHelper.instance.deleteCollectionItem(
                        widget.item.id!,
                      );
                    } else {
                      await DatabaseHelper.instance.updateCollectionItem(
                        widget.item.copyWith(
                          selectedPlatforms: updatedPlatforms,
                        ),
                      );
                    }
                    messenger
                      ..removeCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            isLastPlatform
                                ? '"${widget.item.title}" volledig verwijderd uit je collectie.'
                                : '"${widget.item.title}" verwijderd van ${widget.platformName}.',
                          ),
                        ),
                      );
                    widget.onDeleted?.call();
                  }
                },
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text(
                  'Verwijderen',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.orange500,
                  side: const BorderSide(color: AppTheme.orange500),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDeleteFromAllSheet() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${widget.item.title} volledig verwijderen?',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: Icon(LucideIcons.x, color: AppTheme.black),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'De game wordt van elk platform verwijderd. Al je voortgang, speelduur, achievements en instellingen gaan permanent verloren.',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: AppTheme.gray700,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await DatabaseHelper.instance.deleteCollectionItemsByApiId(
                    widget.item.apiId,
                  );
                  messenger
                    ..removeCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          '"${widget.item.title}" volledig verwijderd uit je collectie.',
                        ),
                      ),
                    );
                  widget.onDeleted?.call();
                },
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text(
                  'Volledig verwijderen',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.orange500,
                  side: const BorderSide(color: AppTheme.orange500),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRefreshDataRow() {
    return InkWell(
      onTap: _isRefreshing ? null : _refreshGameData,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            if (_isRefreshing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.orange500,
                ),
              )
            else
              const Icon(
                LucideIcons.refreshCcw,
                size: 18,
                color: AppTheme.orange500,
              ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Ophalen van nieuwe gegevens',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.orange500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshGameData() async {
    final apiKey = dotenv.env['RAWG_API_KEY'] ?? '';
    if (apiKey.isEmpty) return;
    setState(() => _isRefreshing = true);
    final messenger = ScaffoldMessenger.of(context);
    final client = http.Client();
    try {
      final api = const RawgGamesApi();
      final details = await api.fetchGameDetails(
        client: client,
        apiKey: apiKey,
        id: widget.item.apiId,
      );
      final achievements = await api.fetchGameAchievements(
        client: client,
        apiKey: apiKey,
        id: widget.item.apiId,
      );
      final allItems = await DatabaseHelper.instance.getCollectionItemsByApiId(
        widget.item.apiId,
      );
      for (final existing in allItems) {
        final updated = existing.copyWith(
          title: details.title,
          coverUrl: details.coverUrl ?? existing.coverUrl,
          publisher: details.publishers.isNotEmpty
              ? details.publishers.first
              : existing.publisher,
          suggestedTags: details.tags.take(12).toList(),
          availablePlatforms: details.platforms,
        );
        await DatabaseHelper.instance.updateCollectionItem(updated);
      }
      if (achievements.isNotEmpty) {
        await DatabaseHelper.instance.upsertAchievementsForGame(
          widget.item.apiId,
          achievements,
        );
      }
      await _loadPlatformCount();
      final refreshed = await DatabaseHelper.instance.getCollectionItemById(
        widget.item.id!,
      );
      if (mounted && refreshed != null) {
        widget.onItemChanged?.call(refreshed);
      }
      if (mounted) {
        messenger
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Gamegegevens zijn bijgewerkt.')),
          );
      }
    } on SocketException {
      if (mounted) {
        messenger
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Geen internetverbinding.')),
          );
      }
    } on TimeoutException {
      if (mounted) {
        messenger
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Er is iets misgegaan.')),
          );
      }
    } catch (_) {
      if (mounted) {
        messenger
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Er is iets misgegaan.')),
          );
      }
    } finally {
      client.close();
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Widget _buildAddPlatformRow() {
    return InkWell(
      onTap: _showAddPlatformSheet,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(LucideIcons.circlePlus, size: 18, color: AppTheme.orange500),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Toevoegen aan ander platform',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.orange500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPlatformSheet() async {
    final unownedPlatforms = _availablePlatforms
        .where((p) => !_alreadyAddedPlatformNames.contains(p))
        .toList();
    if (unownedPlatforms.isEmpty) return;
    await AddPlatformSheet.show(
      context,
      item: widget.item,
      unownedPlatforms: unownedPlatforms,
      onAdded: () async {
        await _loadPlatformCount();
        widget.onItemChanged?.call(widget.item);
      },
    );
  }

  Widget _buildDeleteFromPlatformRow() {
    return InkWell(
      onTap: _showDeleteFromPlatformSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            const Icon(LucideIcons.trash2, size: 18, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Verwijder van ${widget.platformName}',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteFromAllRow() {
    return InkWell(
      onTap: _showDeleteFromAllSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            const Icon(LucideIcons.trash2, size: 18, color: Colors.red),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Verwijder van elk platform',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Platform Sheet ────────────────────────────────────────────────────────
// Delegated to widgets/add_platform_sheet.dart (AddPlatformSheet)
