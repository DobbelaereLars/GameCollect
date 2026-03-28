import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/collection_item.dart';
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

  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _requirementTitleController =
      TextEditingController();

  CollectionItem? _item;
  bool _isLoading = true;
  bool _showDisabledRequirements = false;
  bool _hasOpenedTagsOnStart = false;

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
    _hoursController.dispose();
    _minutesController.dispose();
    _requirementTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadItem() async {
    setState(() {
      _isLoading = true;
    });

    final item = await DatabaseHelper.instance.getCollectionItemById(
      widget.itemId,
    );
    if (!mounted) {
      return;
    }

    if (item == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _item = item;
      _isLoading = false;
    });

    if (widget.openTagsOnStart && !_hasOpenedTagsOnStart) {
      _hasOpenedTagsOnStart = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
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

  Future<void> _toggleRequirementCompletion(
    GameRequirement requirement,
    bool value,
  ) async {
    final item = _item;
    if (item == null) return;

    final updated = item.requirements
        .map((r) => r.id == requirement.id ? r.copyWith(isCompleted: value) : r)
        .toList(growable: false);

    await _persistItem(item.copyWith(requirements: updated));
  }

  Future<void> _toggleRequirementEnabled(
    GameRequirement requirement,
    bool enabled,
  ) async {
    final item = _item;
    if (item == null) return;

    final updated = item.requirements
        .map((r) => r.id == requirement.id ? r.copyWith(isEnabled: enabled) : r)
        .toList(growable: false);

    await _persistItem(item.copyWith(requirements: updated));
  }

  Future<void> _addCustomRequirement() async {
    final item = _item;
    if (item == null) return;

    final title = _requirementTitleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    final requirement = GameRequirement(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      description: '',
      isCompleted: false,
      isCustom: true,
      isEnabled: true,
    );

    final updated = List<GameRequirement>.from(item.requirements)
      ..add(requirement);
    _requirementTitleController.clear();
    await _persistItem(
      item.copyWith(requirements: updated, isManuallyCompleted: false),
    );
  }

  Future<void> _toggleManualCompleted(bool value) async {
    final item = _item;
    if (item == null) return;
    await _persistItem(item.copyWith(isManuallyCompleted: value));
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

    final enabledRequirements = item.enabledRequirements;
    final hasProgressFromRequirements = enabledRequirements.isNotEmpty;
    final progressText = hasProgressFromRequirements
        ? '${(item.progressRatio * 100).round()}% (${item.completedEnabledRequirementsCount}/${enabledRequirements.length})'
        : (item.isManuallyCompleted ? '100%' : '0%');

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
                    const SizedBox(height: 12),
                    _buildSection(
                      title: 'Progressie',
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(
                          LucideIcons.ellipsisVertical,
                          color: AppTheme.gray700,
                          size: 18,
                        ),
                        onSelected: (value) {
                          if (value == 'toggle_disabled') {
                            setState(() {
                              _showDisabledRequirements =
                                  !_showDisabledRequirements;
                            });
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'toggle_disabled',
                            child: Text(
                              _showDisabledRequirements
                                  ? 'Verberg niet-gebruikte achievements'
                                  : 'Toon niet-gebruikte achievements',
                            ),
                          ),
                        ],
                      ),
                      child: _buildProgressSection(item, progressText),
                    ),
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

  Widget _buildProgressSection(CollectionItem item, String progressText) {
    final visibleRequirements = item.requirements
        .where((r) => r.isEnabled || _showDisabledRequirements)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voortgang: $progressText',
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: AppTheme.black,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: item.progressRatio,
          minHeight: 8,
          borderRadius: BorderRadius.circular(999),
          backgroundColor: AppTheme.orange100,
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.orange500),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _requirementTitleController,
                cursorColor: AppTheme.orange600,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  color: AppTheme.black,
                ),
                decoration: _orangeInputDecoration(
                  hintText: 'Voeg eigen requirement/achievement toe',
                ),
                onSubmitted: (_) => _addCustomRequirement(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _addCustomRequirement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orange500,
                  foregroundColor: AppTheme.white,
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
        if (visibleRequirements.isEmpty)
          SwitchListTile.adaptive(
            value: item.isManuallyCompleted,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.orange500,
            title: const Text('Markeer deze game als 100% completed'),
            subtitle: const Text(
              'Er zijn geen achievements of requirements actief.',
            ),
            onChanged: _toggleManualCompleted,
          )
        else
          Column(
            children: visibleRequirements.map((requirement) {
              final disabled = !requirement.isEnabled;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: disabled ? AppTheme.gray100 : AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.gray100),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  leading: Checkbox(
                    value: requirement.isCompleted,
                    onChanged: disabled
                        ? null
                        : (value) => _toggleRequirementCompletion(
                            requirement,
                            value ?? false,
                          ),
                    activeColor: AppTheme.orange500,
                  ),
                  title: Text(
                    requirement.title,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: AppTheme.black,
                    ),
                  ),
                  subtitle: requirement.description.isEmpty
                      ? Text(
                          requirement.isCustom
                              ? (disabled
                                    ? 'Eigen requirement (niet gebruikt)'
                                    : 'Eigen requirement')
                              : (disabled
                                    ? 'RAWG achievement (niet gebruikt)'
                                    : 'RAWG achievement'),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                            color: AppTheme.gray500,
                          ),
                        )
                      : Text(
                          requirement.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                            color: AppTheme.gray500,
                          ),
                        ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(
                      LucideIcons.ellipsisVertical,
                      size: 18,
                      color: AppTheme.gray700,
                    ),
                    onSelected: (value) {
                      if (value == 'disable') {
                        _toggleRequirementEnabled(requirement, false);
                      }
                      if (value == 'enable') {
                        _toggleRequirementEnabled(requirement, true);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: requirement.isEnabled ? 'disable' : 'enable',
                        child: Text(
                          requirement.isEnabled
                              ? 'Niet gebruiken in progressie'
                              : 'Opnieuw gebruiken in progressie',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
