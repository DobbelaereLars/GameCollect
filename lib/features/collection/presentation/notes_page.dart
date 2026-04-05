import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({
    super.key,
    required this.itemId,
    required this.initialNotes,
  });

  final int itemId;
  final String initialNotes;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;
  bool _isDirty = false;

  // Undo/redo history — snapshots taken after each debounce save
  final List<String> _history = [];
  int _historyIndex = -1;
  bool _skipHistoryUpdate = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNotes);
    _focusNode = FocusNode();
    _history.add(widget.initialNotes);
    _historyIndex = 0;
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_skipHistoryUpdate) return;
    _isDirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _commitChange);
  }

  void _commitChange() {
    final text = _controller.text;
    _isDirty = false;
    _save(text);
    if (_history[_historyIndex] != text) {
      if (_historyIndex < _history.length - 1) {
        _history.removeRange(_historyIndex + 1, _history.length);
      }
      _history.add(text);
      _historyIndex = _history.length - 1;
      if (mounted) setState(() {});
    }
  }

  Future<void> _save(String text) async {
    final item = await DatabaseHelper.instance.getCollectionItemById(
      widget.itemId,
    );
    if (item == null) return;
    await DatabaseHelper.instance.updateCollectionItem(
      item.copyWith(notes: text),
    );
  }

  Future<void> _popWithSave() async {
    _debounce?.cancel();
    if (_isDirty) {
      _isDirty = false;
      await _save(_controller.text);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _undo() {
    if (_historyIndex <= 0) return;
    _debounce?.cancel();
    _historyIndex--;
    _applyEntry();
  }

  void _redo() {
    if (_historyIndex >= _history.length - 1) return;
    _debounce?.cancel();
    _historyIndex++;
    _applyEntry();
  }

  void _applyEntry() {
    final text = _history[_historyIndex];
    _skipHistoryUpdate = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _skipHistoryUpdate = false;
    _save(text);
    setState(() {});
  }

  void _showClearDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Notities wissen',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: AppTheme.black,
          ),
        ),
        content: const Text(
          'Ben je zeker dat je alle notities wil verwijderen?',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: AppTheme.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: AppTheme.gray700),
            child: const Text('Annuleren'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _debounce?.cancel();
              _skipHistoryUpdate = true;
              _controller.clear();
              _skipHistoryUpdate = false;
              if (_historyIndex < _history.length - 1) {
                _history.removeRange(_historyIndex + 1, _history.length);
              }
              _history.add('');
              _historyIndex = _history.length - 1;
              _save('');
              setState(() {});
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.orange500,
              side: const BorderSide(color: AppTheme.orange500),
            ),
            child: const Text('Wissen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUndo = _historyIndex > 0;
    final canRedo = _historyIndex < _history.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _popWithSave();
      },
      child: Scaffold(
        backgroundColor: AppTheme.white,
        appBar: AppBar(
          backgroundColor: AppTheme.white,
          foregroundColor: AppTheme.black,
          surfaceTintColor: AppTheme.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: _popWithSave,
          ),
          title: const Text(
            'Notities',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: AppTheme.black,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Ongedaan maken',
              icon: Icon(
                LucideIcons.undo2,
                size: 20,
                color: canUndo ? AppTheme.black : AppTheme.gray300,
              ),
              onPressed: canUndo ? _undo : null,
            ),
            IconButton(
              tooltip: 'Opnieuw',
              icon: Icon(
                LucideIcons.redo2,
                size: 20,
                color: canRedo ? AppTheme.black : AppTheme.gray300,
              ),
              onPressed: canRedo ? _redo : null,
            ),
            IconButton(
              tooltip: 'Notities wissen',
              icon: const Icon(
                LucideIcons.trash2,
                size: 20,
                color: AppTheme.orange500,
              ),
              onPressed: _showClearDialog,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _focusNode.requestFocus(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                cursorColor: AppTheme.orange500,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.7,
                  color: AppTheme.black,
                ),
                decoration: const InputDecoration(
                  hintText: 'Begin met typen...',
                  hintStyle: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.7,
                    color: AppTheme.gray300,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
