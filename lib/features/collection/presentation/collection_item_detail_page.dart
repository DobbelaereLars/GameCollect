import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/collection_item.dart';
import 'disabled_achievements_page.dart';
import 'notes_page.dart';

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

  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();

  CollectionItem? _item;
  bool _isLoading = true;
  bool _hasOpenedTagsOnStart = false;
  List<GameAchievementWithState> _achievements = [];
  // Stable display order — only re-sorted after the delay timer fires
  List<GameAchievementWithState> _displayAchievements = [];

  // Achievement pagination & delayed sort
  int _achievementPage = 0;
  Timer? _sortTimer;

  InputDecoration _orangeInputDecoration({
    String? hintText,
    String? labelText,
    bool isDense = true,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      isDense: isDense,
      hintStyle: const TextStyle(
        fontFamily: 'Manrope',
        color: AppTheme.gray500,
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Manrope',
        color: AppTheme.orange700,
      ),
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
    _hoursController.dispose();
    _minutesController.dispose();
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
                          icon: const Icon(
                            LucideIcons.x,
                            color: AppTheme.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (step == 1)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
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
                        const Text(
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
                              style: const TextStyle(
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
                                foregroundColor: AppTheme.white,
                                disabledBackgroundColor: AppTheme.orange100,
                                disabledForegroundColor: AppTheme.white,
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addPlaytime() async {
    final item = _item;
    if (item == null) return;

    final hours = int.tryParse(_hoursController.text.trim()) ?? 0;
    final minutes = int.tryParse(_minutesController.text.trim()) ?? 0;
    final total = max(0, hours * 60 + minutes);

    if (total <= 0) {
      return;
    }

    final now = DateTime.now();
    final dateKey = _toDateKey(now);

    final entries = List<PlaytimeEntry>.from(item.playtimeEntries);
    final existingIndex = entries.indexWhere((e) => e.date == dateKey);
    if (existingIndex >= 0) {
      final existing = entries[existingIndex];
      entries[existingIndex] = PlaytimeEntry(
        date: existing.date,
        minutes: existing.minutes + total,
      );
    } else {
      entries.add(PlaytimeEntry(date: dateKey, minutes: total));
    }

    _hoursController.clear();
    _minutesController.clear();

    await _persistItem(item.copyWith(playtimeEntries: entries));
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
                        errorBuilder: (_, e, s) => Container(
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
                  style: const TextStyle(
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
                    style: const TextStyle(
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
                      const Icon(
                        LucideIcons.users,
                        size: 14,
                        color: AppTheme.gray500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${achievement.percent!.toStringAsFixed(1)}% van spelers behaald',
                        style: const TextStyle(
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
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.gray700,
              ),
              child: const Text('Sluiten'),
            ),
          ],
        );
      },
    );
  }

  String _toDateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatMinutes(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) {
      return '$minutes min';
    }
    return '${hours}u ${minutes}m';
  }

  String _formatDateLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 3) {
      return key;
    }
    return '${parts[2]}/${parts[1]}';
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
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(item),
                    const SizedBox(height: 12),
                    _buildSection(
                      title: 'Speeltijd',
                      child: _buildPlaytimeSection(item),
                    ),
                    const SizedBox(height: 24),
                    _buildAchievementsSection(),
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
                color: AppTheme.white,
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
                item.coverUrl != null
                    ? Image.network(
                        item.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildCoverPlaceholder(),
                      )
                    : _buildCoverPlaceholder(),
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
          style: const TextStyle(
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
                  style: const TextStyle(
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
                backgroundColor: AppTheme.orange100,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.orange500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(item.progressRatio * 100).round()}%',
              style: const TextStyle(
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
    Color textColor = AppTheme.gray500,
  }) {
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
              color: textColor,
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
      child: const Center(
        child: Icon(LucideIcons.gamepad2, color: AppTheme.black, size: 30),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border.all(color: AppTheme.gray100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: AppTheme.black,
                  ),
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildPlaytimeSection(CollectionItem item) {
    final sortedEntries = List<PlaytimeEntry>.from(item.playtimeEntries)
      ..sort((a, b) => a.date.compareTo(b.date));
    final chartEntries = sortedEntries.length <= 10
        ? sortedEntries
        : sortedEntries.sublist(sortedEntries.length - 10);
    final maxMinutes = chartEntries.isEmpty
        ? 0
        : chartEntries.map((e) => e.minutes).reduce(max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Totaal: ${_formatMinutes(item.totalPlaytimeMinutes)} (${item.totalPlaytimeMinutes} min)',
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: AppTheme.black,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hoursController,
                keyboardType: TextInputType.number,
                cursorColor: AppTheme.orange600,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  color: AppTheme.black,
                ),
                decoration: _orangeInputDecoration(labelText: 'Uren'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _minutesController,
                keyboardType: TextInputType.number,
                cursorColor: AppTheme.orange600,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  color: AppTheme.black,
                ),
                decoration: _orangeInputDecoration(labelText: 'Minuten'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _addPlaytime,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orange500,
                  foregroundColor: AppTheme.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Opslaan'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (chartEntries.isEmpty)
          const Text(
            'Nog geen speelduur toegevoegd.',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: AppTheme.gray500,
            ),
          )
        else
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: chartEntries.map((entry) {
                final fraction = maxMinutes == 0
                    ? 0.0
                    : entry.minutes / maxMinutes;
                final height = 24 + (fraction * 96);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${entry.minutes}m',
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                            color: AppTheme.gray700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: AppTheme.orange500,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDateLabel(entry.date),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                            color: AppTheme.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
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
            const Expanded(
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
                  style: const TextStyle(
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
                              errorBuilder: (_, e, s) =>
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
                          color: isDisabled
                              ? AppTheme.gray300
                              : AppTheme.black,
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
}
