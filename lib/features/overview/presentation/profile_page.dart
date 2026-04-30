import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _version = '';
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
    _syncNotificationState();
  }

  Future<void> _syncNotificationState() async {
    final systemGranted =
        await NotificationService.instance.arePermissionsGranted();
    final dbEnabled =
        await DatabaseHelper.instance.getNotificationsEnabled();

    // If system permission is revoked, correct the DB so it stays in sync.
    if (!systemGranted && dbEnabled) {
      await DatabaseHelper.instance.setNotificationsEnabled(false);
    }

    if (mounted) {
      setState(() => _notificationsEnabled = systemGranted && dbEnabled);
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  Future<void> _resetApp(BuildContext context) async {
    // Close and delete the database file
    final db = await DatabaseHelper.instance.database;
    final dbPath = db.path;
    await db.close();
    DatabaseHelper.resetInstance();

    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }

    if (!context.mounted) return;

    // Force app restart by pushing a full-screen blocker
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const _RestartPromptScreen()),
      (_) => false,
    );
  }

  Future<void> _showResetConfirmSheet(BuildContext context) async {
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
                  const Expanded(
                    child: Text(
                      'App resetten?',
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
                    icon: const Icon(LucideIcons.x, color: AppTheme.black),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Alle games, speelduur, notities, achievements en instellingen worden permanent verwijderd. Dit kan niet ongedaan worden gemaakt.',
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
                  await _resetApp(context);
                },
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text(
                  'Alles verwijderen en resetten',
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

  // ── Build ─────────────────────────────────────────────────────────────────

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
          'Profiel & Instellingen',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Notifications ──────────────────────────────────────────────
              _buildSectionLabel('Meldingen'),
              _buildToggleRow(
                icon: LucideIcons.bell,
                label: 'Meldingen inschakelen',
                subtitle: 'Herinneringen en voortgangsmeldingen',
                value: _notificationsEnabled,
                onChanged: (val) async {
                  if (val) {
                    final granted = await NotificationService.instance
                        .requestPermissions();
                    if (!granted) {
                      if (mounted) {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Sta meldingen toe in Instellingen van je apparaat.',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    setState(() => _notificationsEnabled = true);
                    await DatabaseHelper.instance.setNotificationsEnabled(true);
                    await NotificationService.instance.scheduleAll();
                  } else {
                    setState(() => _notificationsEnabled = false);
                    await DatabaseHelper.instance
                        .setNotificationsEnabled(false);
                    await NotificationService.instance.cancelAll();
                  }
                },
              ),
              const Divider(height: 1, thickness: 1, color: AppTheme.gray100),
              // ── Data ────────────────────────────────────────────────────
              _buildSectionLabel('Gegevens'),
              _buildActionRow(
                context: context,
                icon: LucideIcons.trash2,
                label: 'App resetten',
                subtitle: 'Verwijdert alle games en gegevens',
                iconColor: AppTheme.orange500,
                onTap: () => _showResetConfirmSheet(context),
              ),
              const Divider(height: 1, thickness: 1, color: AppTheme.gray100),
              // ── App info ────────────────────────────────────────────────
              _buildSectionLabel('Over de app'),
              _buildInfoRow(
                icon: LucideIcons.gamepad2,
                label: 'GameCollect',
                value: _version.isEmpty ? '—' : 'Versie $_version',
              ),
              const Divider(height: 1, thickness: 1, color: AppTheme.gray100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.gray500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.orange500),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.black,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.orange500),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.black,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.gray500,
                    ),
                  ),
                ],
              ],
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
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    String? subtitle,
    Color iconColor = AppTheme.orange500,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.black,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: AppTheme.gray300,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Restart prompt shown after reset
// ─────────────────────────────────────────────────────────────────────────────

class _RestartPromptScreen extends StatelessWidget {
  const _RestartPromptScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.refreshCcw,
                size: 48,
                color: AppTheme.orange500,
              ),
              const SizedBox(height: 24),
              const Text(
                'App resetten gelukt',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Alle gegevens zijn verwijderd. Sluit de app af en open hem opnieuw om opnieuw te beginnen.',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: AppTheme.gray700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
