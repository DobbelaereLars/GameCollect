import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/collection_item.dart';

class PlaytimePage extends StatefulWidget {
  const PlaytimePage({
    super.key,
    required this.itemId,
    required this.gameTitle,
    required this.initialEntries,
  });

  final int itemId;
  final String gameTitle;
  final List<PlaytimeEntry> initialEntries;

  @override
  State<PlaytimePage> createState() => _PlaytimePageState();
}

class _PlaytimePageState extends State<PlaytimePage> {
  late List<PlaytimeEntry> _entries;

  // 0 = current week, -1 = previous week, etc.
  int _weekOffset = 0;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _entries = List<PlaytimeEntry>.from(widget.initialEntries);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Date helpers ────────────────────────────────────────────────────────────

  String _toDateKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  DateTime _mondayOfCurrentWeek() {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
  }

  int _weekOffsetForDate(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return 0;
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final currentMonday = _mondayOfCurrentWeek();
    return monday.difference(currentMonday).inDays ~/ 7;
  }

  DateTime _mondayOfDisplayedWeek() {
    return _mondayOfCurrentWeek().add(Duration(days: _weekOffset * 7));
  }

  List<DateTime> _weekDays() {
    final monday = _mondayOfDisplayedWeek();
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  bool get _isCurrentWeek => _weekOffset == 0;

  int _minutesForDay(DateTime day) {
    final key = _toDateKey(day);
    return _entries
        .where((e) => e.date == key)
        .fold(0, (s, e) => s + e.minutes);
  }

  int get _totalAll => _entries.fold(0, (s, e) => s + e.minutes);

  int _weekTotal() {
    return _weekDays().fold(0, (s, d) => s + _minutesForDay(d));
  }

  // ─── Formatting ──────────────────────────────────────────────────────────────

  String _formatMinutesShort(int m) {
    if (m == 0) return '';
    final h = m ~/ 60;
    final min = m % 60;
    if (h == 0) return '${min}m';
    if (min == 0) return '${h}u';
    return '${h}u${min}m';
  }

  String _formatMinutesLong(int m) {
    if (m == 0) return '0 min';
    final h = m ~/ 60;
    final min = m % 60;
    if (h == 0) return '$min min';
    if (min == 0) return '${h}u';
    return '${h}u ${min}m';
  }

  String _weekRangeLabel() {
    final days = _weekDays();
    final start = days.first;
    final end = days.last;
    const months = [
      'jan',
      'feb',
      'mrt',
      'apr',
      'mei',
      'jun',
      'jul',
      'aug',
      'sep',
      'okt',
      'nov',
      'dec',
    ];
    if (start.month == end.month) {
      return '${start.day} – ${end.day} ${months[end.month - 1]}';
    }
    return '${start.day} ${months[start.month - 1]} – ${end.day} ${months[end.month - 1]}';
  }

  static const List<String> _dayLabels = [
    'Ma',
    'Di',
    'Wo',
    'Do',
    'Vr',
    'Za',
    'Zo',
  ];

  // ─── Save playtime ────────────────────────────────────────────────────────────

  Future<void> _savePlaytime(int hours, int minutes) async {
    final total = hours * 60 + minutes;
    if (total <= 0) return;

    final now = DateTime.now();
    final newEntry = PlaytimeEntry(
      id: now.microsecondsSinceEpoch.toString(),
      date: _toDateKey(now),
      minutes: total,
      addedAt: now,
    );

    final updated = [..._entries, newEntry];

    final item = await DatabaseHelper.instance.getCollectionItemById(
      widget.itemId,
    );
    if (item == null) return;
    await DatabaseHelper.instance.updateCollectionItem(
      item.copyWith(playtimeEntries: updated),
    );

    if (!mounted) return;
    setState(() {
      _entries = updated;
      _weekOffset = 0;
    });
  }

  // ─── Bottom sheet ─────────────────────────────────────────────────────────────

  void _showAddPlaytimeSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return _AddPlaytimeSheet(onSave: _savePlaytime);
      },
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final weekDays = _weekDays();
    final minutes = weekDays.map(_minutesForDay).toList();
    final maxMinutes = minutes.reduce(max);
    final today = _toDateKey(DateTime.now());

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Speelduur',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              widget.gameTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.gray500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final updated = await Navigator.of(context)
                  .push<List<PlaytimeEntry>>(
                    MaterialPageRoute<List<PlaytimeEntry>>(
                      builder: (_) => _PlaytimeHistoryPage(
                        itemId: widget.itemId,
                        initialEntries: _entries,
                      ),
                    ),
                  );
              if (updated != null && mounted) {
                setState(() => _entries = updated);
              }
            },
            icon: const Icon(
              LucideIcons.clipboardList,
              size: 22,
              color: AppTheme.orange500,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            const SizedBox(height: 16),

            // ── Total playtime card ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.orange50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.orange100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.clock,
                      size: 20,
                      color: AppTheme.orange600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Totale speelduur',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.orange700,
                        ),
                      ),
                      Text(
                        _formatMinutesLong(_totalAll),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.orange600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Week chart card ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                border: Border.all(color: AppTheme.gray100),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Week navigation row
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(() => _weekOffset--),
                        icon: const Icon(
                          LucideIcons.chevronLeft,
                          size: 20,
                          color: AppTheme.black,
                        ),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _weekRangeLabel(),
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.black,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isCurrentWeek
                            ? null
                            : () => setState(() => _weekOffset++),
                        icon: Icon(
                          LucideIcons.chevronRight,
                          size: 20,
                          color: _isCurrentWeek
                              ? AppTheme.gray300
                              : AppTheme.black,
                        ),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Week total
                  Text(
                    _weekTotal() == 0
                        ? 'Geen speelduur deze week'
                        : 'Totaal: ${_formatMinutesLong(_weekTotal())}',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: _weekTotal() == 0
                          ? AppTheme.gray300
                          : AppTheme.gray500,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bar chart
                  SizedBox(
                    height: 180,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (i) {
                        final day = weekDays[i];
                        final dayKey = _toDateKey(day);
                        final mins = minutes[i];
                        final isToday = dayKey == today;
                        final fraction = maxMinutes == 0
                            ? 0.0
                            : mins / maxMinutes;
                        // Min bar height 4 so empty days still show a stub
                        final barHeight = mins == 0
                            ? 4.0
                            : 12 + (fraction * 100);

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Value label — only shown when non-zero
                                SizedBox(
                                  height: 20,
                                  child: mins > 0
                                      ? Text(
                                          _formatMinutesShort(mins),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isToday
                                                ? AppTheme.orange600
                                                : AppTheme.gray700,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 4),
                                // Bar
                                Container(
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color: mins == 0
                                        ? AppTheme.gray100
                                        : (isToday
                                              ? AppTheme.orange500
                                              : AppTheme.orange300),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Day label (Ma, Di, …)
                                Text(
                                  _dayLabels[i],
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 11,
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isToday
                                        ? AppTheme.orange500
                                        : AppTheme.gray500,
                                  ),
                                ),
                                // Date number
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                    color: isToday
                                        ? AppTheme.orange500
                                        : AppTheme.gray300,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Add playtime button ────────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: _showAddPlaytimeSheet,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Speelduur toevoegen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.orange500,
                side: const BorderSide(color: AppTheme.orange500),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── History list ──────────────────────────────────────────────────
            if (_entries.isNotEmpty) ...[
              const Text(
                'Geschiedenis',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 10),
              Material(
                color: AppTheme.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppTheme.gray100),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: () {
                    // Group by date, sum minutes per day
                    final Map<String, int> byDate = {};
                    for (final e in _entries) {
                      byDate[e.date] = (byDate[e.date] ?? 0) + e.minutes;
                    }
                    final sortedDates = byDate.keys.toList()
                      ..sort((a, b) => b.compareTo(a));
                    return sortedDates.asMap().entries.map((mapEntry) {
                      final idx = mapEntry.key;
                      final dateKey = mapEntry.value;
                      final isLast = idx == sortedDates.length - 1;
                      final synthetic = PlaytimeEntry(
                        id: dateKey,
                        date: dateKey,
                        minutes: byDate[dateKey]!,
                        addedAt: DateTime.now(),
                      );
                      return _buildHistoryTile(synthetic, isLast: isLast);
                    }).toList();
                  }(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTile(PlaytimeEntry entry, {required bool isLast}) {
    final parts = entry.date.split('-');
    final dateLabel = parts.length == 3
        ? '${parts[2]}/${parts[1]}/${parts[0]}'
        : entry.date;

    final isActive = _weekOffsetForDate(entry.date) == _weekOffset;

    final topRadius = Radius.circular(isActive ? 12 : 0);
    final bottomRadius = Radius.circular(isActive || isLast ? 12 : 0);
    final borderRadius = BorderRadius.only(
      topLeft: topRadius,
      topRight: topRadius,
      bottomLeft: bottomRadius,
      bottomRight: bottomRadius,
    );

    return Column(
      children: [
        Ink(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: borderRadius,
          ),
          child: InkWell(
            onTap: () {
              final offset = _weekOffsetForDate(entry.date);
              setState(() => _weekOffset = offset);
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
              );
            },
            borderRadius: borderRadius,
            splashColor: AppTheme.orange100,
            highlightColor: AppTheme.orange50,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.calendarDays,
                    size: 16,
                    color: isActive ? AppTheme.orange500 : AppTheme.orange500,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive ? AppTheme.orange500 : AppTheme.black,
                      ),
                    ),
                  ),
                  Text(
                    _formatMinutesLong(entry.minutes),
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppTheme.orange500 : AppTheme.orange600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, thickness: 1, color: AppTheme.gray100),
      ],
    );
  }
}

// ─── Add Playtime Sheet ────────────────────────────────────────────────────────

class _AddPlaytimeSheet extends StatefulWidget {
  const _AddPlaytimeSheet({required this.onSave});

  final Future<void> Function(int hours, int minutes) onSave;

  @override
  State<_AddPlaytimeSheet> createState() => _AddPlaytimeSheetState();
}

class _AddPlaytimeSheetState extends State<_AddPlaytimeSheet> {
  int _hours = 0;
  int _minutes = 0;
  bool _isSaving = false;

  bool get _canSave => (_hours > 0 || _minutes > 0) && !_isSaving;

  void _increment(bool isHours) {
    setState(() {
      if (isHours) {
        _hours = (_hours + 1).clamp(0, 23);
      } else {
        _minutes = (_minutes + 5).clamp(0, 55);
      }
    });
  }

  void _decrement(bool isHours) {
    setState(() {
      if (isHours) {
        _hours = (_hours - 1).clamp(0, 23);
      } else {
        _minutes = (_minutes - 5).clamp(0, 55);
      }
    });
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSave(_hours, _minutes);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + 40;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Speelduur toevoegen',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.x, color: AppTheme.black),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Wordt opgeslagen op vandaag, ${_todayLabel()}',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.gray500,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Steppers row
          Row(
            children: [
              Expanded(
                child: _buildStepper(
                  label: 'Uren',
                  value: _hours,
                  onIncrement: () => _increment(true),
                  onDecrement: () => _decrement(true),
                  canDecrement: _hours > 0,
                  canIncrement: _hours < 23,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStepper(
                  label: 'Minuten',
                  value: _minutes,
                  displayValue: _minutes.toString().padLeft(2, '0'),
                  onIncrement: () => _increment(false),
                  onDecrement: () => _decrement(false),
                  canDecrement: _minutes > 0,
                  canIncrement: _minutes < 55,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canSave ? _handleSave : null,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.white,
                      ),
                    )
                  : const Icon(LucideIcons.save, size: 18),
              label: const Text('Opslaan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orange500,
                foregroundColor: AppTheme.white,
                disabledBackgroundColor: AppTheme.orange100,
                disabledForegroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper({
    required String label,
    required int value,
    String? displayValue,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required bool canDecrement,
    required bool canIncrement,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.gray500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.orange200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Decrement
              _stepperButton(
                icon: LucideIcons.minus,
                onPressed: canDecrement ? onDecrement : null,
                leftSide: true,
              ),
              // Value
              Expanded(
                child: Text(
                  displayValue ?? '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.black,
                  ),
                ),
              ),
              // Increment
              _stepperButton(
                icon: LucideIcons.plus,
                onPressed: canIncrement ? onIncrement : null,
                leftSide: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool leftSide,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: leftSide
            ? const BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              )
            : const BorderRadius.only(
                topRight: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Icon(
            icon,
            size: 18,
            color: onPressed == null ? AppTheme.gray300 : AppTheme.orange500,
          ),
        ),
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      'jan',
      'feb',
      'mrt',
      'apr',
      'mei',
      'jun',
      'jul',
      'aug',
      'sep',
      'okt',
      'nov',
      'dec',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

// ─── History Page ─────────────────────────────────────────────────────────────

class _PlaytimeHistoryPage extends StatefulWidget {
  const _PlaytimeHistoryPage({
    required this.itemId,
    required this.initialEntries,
  });

  final int itemId;
  final List<PlaytimeEntry> initialEntries;

  @override
  State<_PlaytimeHistoryPage> createState() => _PlaytimeHistoryPageState();
}

class _PlaytimeHistoryPageState extends State<_PlaytimeHistoryPage> {
  late List<PlaytimeEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = List<PlaytimeEntry>.from(widget.initialEntries);
  }

  String _formatDateLabel(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return dateKey;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String _formatMinutesLong(int m) {
    if (m == 0) return '0 min';
    final h = m ~/ 60;
    final min = m % 60;
    if (h == 0) return '$min min';
    if (min == 0) return '${h}u';
    return '${h}u ${min}m';
  }

  String _formatTimeLabel(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _requestDelete(PlaytimeEntry entry) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sessie verwijderen',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      color: AppTheme.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    icon: const Icon(LucideIcons.x, color: AppTheme.black),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Verwijder de sessie van ${_formatDateLabel(entry.date)} om ${_formatTimeLabel(entry.addedAt)} (${_formatMinutesLong(entry.minutes)})?',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.gray500,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text('Verwijderen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.orange500,
                  side: const BorderSide(color: AppTheme.orange500),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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

    if (confirmed != true) return;

    final updated = _entries.where((e) => e.id != entry.id).toList();
    final item = await DatabaseHelper.instance.getCollectionItemById(
      widget.itemId,
    );
    if (item == null) return;
    await DatabaseHelper.instance.updateCollectionItem(
      item.copyWith(playtimeEntries: updated),
    );
    if (!mounted) return;
    setState(() => _entries = updated);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<PlaytimeEntry>.from(_entries)
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_entries);
      },
      child: Scaffold(
        backgroundColor: AppTheme.white,
        appBar: AppBar(
          backgroundColor: AppTheme.white,
          foregroundColor: AppTheme.black,
          surfaceTintColor: AppTheme.white,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: () => Navigator.of(context).pop(_entries),
          ),
          title: const Text(
            'Geschiedenis',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.black,
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: sorted.isEmpty
              ? const Center(
                  child: Text(
                    'Geen sessies opgeslagen.',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.gray500,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: sorted.length,
                  itemBuilder: (_, index) {
                    final entry = sorted[index];
                    final isFirst = index == 0;
                    final isLast = index == sorted.length - 1;

                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        border: Border(
                          left: const BorderSide(color: AppTheme.gray100),
                          right: const BorderSide(color: AppTheme.gray100),
                          top: isFirst
                              ? const BorderSide(color: AppTheme.gray100)
                              : BorderSide.none,
                          bottom: isLast
                              ? const BorderSide(color: AppTheme.gray100)
                              : BorderSide.none,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: isFirst
                              ? const Radius.circular(16)
                              : Radius.zero,
                          topRight: isFirst
                              ? const Radius.circular(16)
                              : Radius.zero,
                          bottomLeft: isLast
                              ? const Radius.circular(16)
                              : Radius.zero,
                          bottomRight: isLast
                              ? const Radius.circular(16)
                              : Radius.zero,
                        ),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.calendarDays,
                                  size: 16,
                                  color: AppTheme.orange500,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatDateLabel(entry.date),
                                        style: const TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.black,
                                        ),
                                      ),
                                      Text(
                                        _formatTimeLabel(entry.addedAt),
                                        style: const TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: AppTheme.gray500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatMinutesLong(entry.minutes),
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.orange600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () => _requestDelete(entry),
                                  icon: const Icon(
                                    LucideIcons.trash2,
                                    size: 16,
                                    color: AppTheme.gray300,
                                  ),
                                  style: IconButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(32, 32),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: AppTheme.gray100,
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
