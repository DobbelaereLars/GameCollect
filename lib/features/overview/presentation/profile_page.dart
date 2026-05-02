import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/sync/auth_service.dart';
import '../../../core/sync/connectivity_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_theme_controller.dart';
import 'auth_page.dart';

/// Profielpagina: toont accountinfo, synchronisatiestatus, meldingen en app-instellingen.
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
    AuthService.instance.addListener(_onSyncOrAuthChange);
    SyncService.instance.addListener(_onSyncOrAuthChange);
    ConnectivityService.instance.addListener(_onSyncOrAuthChange);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onSyncOrAuthChange);
    SyncService.instance.removeListener(_onSyncOrAuthChange);
    ConnectivityService.instance.removeListener(_onSyncOrAuthChange);
    super.dispose();
  }

  /// Reageert op wijzigingen in auth-, sync- of verbindingsstatus.
  void _onSyncOrAuthChange() {
    if (!mounted) return;
    // De meldingsvoorkeur kan zojuist gewijzigd zijn door sync.
    _syncNotificationState();
    setState(() {});
  }

  /// Synchroniseert de meldingsstatus tussen systeemrechten en de database.
  Future<void> _syncNotificationState() async {
    final systemGranted = await NotificationService.instance
        .arePermissionsGranted();
    final dbEnabled = await DatabaseHelper.instance.getNotificationsEnabled();

    // Als systeemtoestemming ingetrokken is, corrigeer de DB zodat deze gesynchroniseerd blijft.
    if (!systemGranted && dbEnabled) {
      await DatabaseHelper.instance.setNotificationsEnabled(false);
    }

    if (mounted) {
      setState(() => _notificationsEnabled = systemGranted && dbEnabled);
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  /// Wist alle lokale data en logt de gebruiker uit na bevestiging.
  Future<void> _resetApp(BuildContext context) async {
    // Eerst uitloggen zodat het toestel geen sessietoken meer heeft.
    // Clouddata blijft intact — de gebruiker kan later opnieuw inloggen.
    if (AuthService.instance.isSignedIn) {
      try {
        await AuthService.instance.signOut();
      } catch (_) {
        // Best-effort; fouten negeren zodat de reset altijd voltooit.
      }
    }

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

    // Forceer herstart van de app door een blokkerend volledig scherm te tonen.
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const _RestartPromptScreen()),
      (_) => false,
    );
  }

  /// Toont een bevestigingssheet vóór het volledig resetten van de app.
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
                  Expanded(
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
                    icon: Icon(LucideIcons.x, color: AppTheme.black),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Account ──────────────────────────────────────────────────
              _buildSectionLabel('Account'),
              ..._buildAccountSection(context),
              Divider(height: 1, thickness: 1, color: AppTheme.gray100),
              // ── Weergave (thema) ────────────────────────────────────────
              _buildSectionLabel('Weergave'),
              _buildThemeRow(),
              Divider(height: 1, thickness: 1, color: AppTheme.gray100),
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
                    await DatabaseHelper.instance.setNotificationsEnabled(
                      false,
                    );
                    await NotificationService.instance.cancelAll();
                  }
                },
              ),
              Divider(height: 1, thickness: 1, color: AppTheme.gray100),
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
              Divider(height: 1, thickness: 1, color: AppTheme.gray100),
              // ── App info ────────────────────────────────────────────────
              _buildSectionLabel('Over de app'),
              _buildInfoRow(
                icon: LucideIcons.gamepad2,
                label: 'GameCollect',
                value: _version.isEmpty ? '—' : 'Versie $_version',
              ),
              Divider(height: 1, thickness: 1, color: AppTheme.gray100),
            ],
          ),
        ),
      ),
    );
  }

  /// Bouwt een sectielabel-widget voor visuele groepering van instellingen.
  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.gray500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Account section ───────────────────────────────────────────────────────

  List<Widget> _buildAccountSection(BuildContext context) {
    final auth = AuthService.instance;
    if (!auth.isAvailable) {
      return [
        _buildInfoRow(
          icon: LucideIcons.cloudOff,
          label: 'Cloud-sync',
          value: 'Niet ingesteld',
        ),
      ];
    }

    if (!auth.isSignedIn) {
      return [
        _buildActionRow(
          context: context,
          icon: LucideIcons.cloudOff,
          label: 'Cloud-sync',
          subtitle: 'Tik om aan te melden of een account aan te maken',
          onTap: () => _openAuthPage(context, AuthMode.signIn),
        ),
      ];
    }

    final sync = SyncService.instance;
    final connectivity = ConnectivityService.instance;
    return [
      _buildInfoRow(
        icon: LucideIcons.userCheck,
        label: 'Aangemeld als',
        value: auth.email ?? '—',
      ),
      _buildSyncStatusRow(sync: sync, online: connectivity.isOnline),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (sync.isSyncing || !connectivity.isOnline)
                ? null
                : () async {
                    final ok = await sync.syncNow();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Synchronisatie voltooid.'
                                : (sync.lastError ?? 'Synchronisatie mislukt.'),
                          ),
                        ),
                      );
                  },
            icon: sync.isSyncing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.trueWhite,
                    ),
                  )
                : const Icon(LucideIcons.refreshCw, size: 20),
            label: Text(
              sync.isSyncing
                  ? 'Bezig met synchroniseren…'
                  : 'Nu synchroniseren',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style:
                OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.orange500,
                  side: const BorderSide(color: AppTheme.orange500, width: 2),
                  disabledForegroundColor: AppTheme.trueWhite,
                  disabledBackgroundColor: AppTheme.orange100,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ).copyWith(
                  // Verberg de rand als de knop uitgeschakeld is zodat het overeenkomt
                  // met het app-brede patroon "uitgeschakeld = oranje100 achtergrond met witte tekst".
                  side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return BorderSide.none;
                    }
                    return const BorderSide(
                      color: AppTheme.orange500,
                      width: 2,
                    );
                  }),
                ),
          ),
        ),
      ),
      _buildActionRow(
        context: context,
        icon: LucideIcons.logOut,
        label: 'Account loskoppelen',
        subtitle:
            'Cloud-sync stopt. Lokale data blijft staan; meld opnieuw aan om verder te synchroniseren.',
        onTap: () => _confirmSignOut(context),
      ),
    ];
  }

  /// Bouwt een rij met synchronisatiestatus (icoon, tekst en tijdstip).
  Widget _buildSyncStatusRow({
    required SyncService sync,
    required bool online,
  }) {
    final IconData icon;
    final String label;
    final String subtitle;
    final Color iconColor;

    if (!online) {
      icon = LucideIcons.cloudOff;
      iconColor = AppTheme.orange700;
      label = 'Geen verbinding';
      final pending = sync.pendingChanges;
      subtitle = pending == 0
          ? 'Synchronisatie hervat zodra je weer online bent.'
          : '$pending wijziging${pending == 1 ? '' : 'en'} wachten op verbinding.';
    } else if (sync.isSyncing) {
      icon = LucideIcons.refreshCw;
      iconColor = AppTheme.orange500;
      label = 'Bezig met synchroniseren';
      subtitle = 'Even geduld…';
    } else if (sync.pendingChanges > 0) {
      icon = LucideIcons.cloudUpload;
      iconColor = AppTheme.orange500;
      final p = sync.pendingChanges;
      label = '$p wijziging${p == 1 ? '' : 'en'} wachten';
      subtitle = 'Tik op "Nu synchroniseren" om te uploaden.';
    } else {
      icon = LucideIcons.cloudCheck;
      iconColor = AppTheme.orange500;
      label = 'Up-to-date';
      final last = sync.lastSyncAt;
      subtitle = last == null
          ? 'Nog niet gesynchroniseerd.'
          : 'Laatst gesynchroniseerd ${_formatRelative(last)}.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
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
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
        ],
      ),
    );
  }

  /// Formatteert een tijdstip relatief t.o.v. nu (bijv. "5 minuten geleden").
  String _formatRelative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'zojuist';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min geleden';
    if (diff.inHours < 24) return '${diff.inHours} u geleden';
    if (diff.inDays < 7) return '${diff.inDays} d geleden';
    return '${time.day}/${time.month}/${time.year}';
  }

  /// Opent de auth-pagina in de opgegeven modus (aanmelden of registreren).
  Future<void> _openAuthPage(BuildContext context, AuthMode mode) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AuthPage(initialMode: mode)),
    );
    if (mounted) setState(() {});
  }

  /// Toont een bevestigingsdialoog vóór het uitloggen.
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Account loskoppelen?',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.black,
            ),
          ),
          content: Text(
            'Cloud-sync stopt. Nieuwe wijzigingen worden niet meer naar de cloud gestuurd. '
            'Je lokale gegevens blijven op dit toestel staan en je gegevens in de cloud blijven bewaard. '
            'Je kunt later opnieuw aanmelden om verder te synchroniseren.',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: AppTheme.gray700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(foregroundColor: AppTheme.gray700),
              child: const Text('Annuleren'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.orange500,
                side: const BorderSide(color: AppTheme.orange500),
              ),
              child: const Text(
                'Loskoppelen',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await AuthService.instance.signOut();
    }
  }

  /// Bouwt een informatierij met icoon, label en waarde.
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
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.black,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
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

  /// Bouwt de themaselectierij die de actieve themamodus toont.
  Widget _buildThemeRow() {
    final controller = AppThemeController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return InkWell(
          onTap: () => _showThemeSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            child: Row(
              children: [
                Icon(LucideIcons.moonStar, size: 18, color: AppTheme.orange500),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Donker thema',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.black,
                    ),
                  ),
                ),
                Text(
                  _labelForMode(controller.mode),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.gray700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: AppTheme.gray500,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Geeft het weergavelabel terug voor een gegeven [ThemeMode].
  String _labelForMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Automatisch';
      case ThemeMode.light:
        return 'Licht';
      case ThemeMode.dark:
        return 'Donker';
    }
  }

  /// Toont een sheet om de themamodus te kiezen (licht, donker of systeem).
  Future<void> _showThemeSheet(BuildContext context) async {
    final controller = AppThemeController.instance;
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final current = controller.mode;
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
                      'Thema aanpassen',
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
                'Kies hoe de app eruit ziet. Bij Automatisch volgt de app de '
                'systeeminstellingen van je toestel.',
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
                children: [ThemeMode.system, ThemeMode.light, ThemeMode.dark]
                    .map((mode) {
                      final isSelected = current == mode;
                      return ChoiceChip(
                        showCheckmark: false,
                        label: Text(_labelForMode(mode)),
                        selected: isSelected,
                        onSelected: (s) {
                          if (s) Navigator.of(sheetContext).pop(mode);
                        },
                        selectedColor: AppTheme.orange500,
                        labelStyle: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppTheme.trueWhite
                              : AppTheme.black,
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
                    })
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      await controller.setMode(selected);
    }
  }

  /// Bouwt een schakelaarrij voor een boolean instelling.
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
                  style: TextStyle(
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
                    style: TextStyle(
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
            child: Switch(value: value, onChanged: onChanged),
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
                    style: TextStyle(
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
                      style: TextStyle(
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
            Icon(LucideIcons.chevronRight, size: 16, color: AppTheme.gray300),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Herstart-prompt getoond na het resetten van de app
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
              Text(
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
              Text(
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
