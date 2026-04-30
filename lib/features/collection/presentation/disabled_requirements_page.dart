import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/collection_item.dart';

class DisabledRequirementsPage extends StatefulWidget {
  const DisabledRequirementsPage({
    super.key,
    required this.initialRequirements,
    required this.onToggleCompleted,
    required this.onToggleEnabled,
    required this.onDelete,
  });

  final List<CustomRequirement> initialRequirements;
  final Future<void> Function(String id, bool value) onToggleCompleted;
  final Future<void> Function(String id, bool enabled) onToggleEnabled;
  final Future<void> Function(String id) onDelete;

  @override
  State<DisabledRequirementsPage> createState() =>
      _DisabledRequirementsPageState();
}

class _DisabledRequirementsPageState extends State<DisabledRequirementsPage> {
  late List<CustomRequirement> _requirements;

  @override
  void initState() {
    super.initState();
    _requirements = List<CustomRequirement>.from(widget.initialRequirements);
  }

  Future<void> _confirmDelete(String id) async {
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
                  await widget.onDelete(id);
                  if (!mounted) return;
                  setState(() => _requirements.removeWhere((r) => r.id == id));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: AppTheme.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Niet meetellen',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: AppTheme.black,
          ),
        ),
      ),
      body: _requirements.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.eye, size: 48, color: AppTheme.gray300),
                    const SizedBox(height: 16),
                    Text(
                      'Geen verborgen vereisten.\nVereisten die je niet wil meetellen in je progressie vind je hier terug.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _requirements.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppTheme.gray100),
              itemBuilder: (context, index) {
                final req = _requirements[index];
                final displayText = req.title?.isNotEmpty == true
                    ? req.title!
                    : req.description;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Checkbox(
                          value: req.isCompleted,
                          onChanged: (value) async {
                            final newVal = value ?? false;
                            await widget.onToggleCompleted(req.id, newVal);
                            if (!mounted) return;
                            setState(() {
                              _requirements[index] = req.copyWith(
                                isCompleted: newVal,
                              );
                            });
                          },
                          activeColor: AppTheme.orange500,
                          side: BorderSide(color: AppTheme.gray300),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          displayText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                            color: AppTheme.gray500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Re-enable button
                      GestureDetector(
                        onTap: () async {
                          await widget.onToggleEnabled(req.id, true);
                          if (!mounted) return;
                          setState(() => _requirements.removeAt(index));
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            LucideIcons.eye,
                            size: 18,
                            color: AppTheme.orange500,
                          ),
                        ),
                      ),
                      // Delete button
                      GestureDetector(
                        onTap: () => _confirmDelete(req.id),
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
              },
            ),
    );
  }
}
