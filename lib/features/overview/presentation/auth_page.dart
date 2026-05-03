import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/sync/auth_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/theme/app_theme.dart';

enum AuthMode { signIn, register }

/// Gecombineerd aanmeld- en registratiescherm. Schakelt tussen modi via een tabkiezer.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.initialMode = AuthMode.signIn});

  /// Initieel weergegeven modus (aanmelden of registreren).
  final AuthMode initialMode;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late AuthMode _mode = widget.initialMode;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocusNode = FocusNode();

  // Indicator: wordt geactiveerd tijdens het versturen van het formulier.
  bool _isSubmitting = false;

  // Wachtwoord verbergen of tonen.
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// Valideert het formulier en roept de juiste Firebase-authenticatiemethode aan.
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // Onderdruk automatische sync tijdens de aanmeldflow zodat de
      // strategiedialoog kans krijgt vóór enige synchronisatie.
      SyncService.instance.suppressAutoSync();
      if (_mode == AuthMode.signIn) {
        await AuthService.instance.signIn(email: email, password: password);
      } else {
        await AuthService.instance.register(email: email, password: password);
      }

      if (!mounted) return;

      // Na aanmelden: vraag de gebruiker hoe lokale en clouddata te combineren,
      // maar alleen als BEIDE kanten data bevatten. In alle andere gevallen is
      // de uitkomst eenduidig (eenrichtings push of pull) en wordt direct gesynchroniseerd.
      // - Registreren: cloud is nieuw → nooit vragen.
      // - Aanmelden met lege lokale data → alleen cloud ophalen → geen vraag.
      // - Aanmelden met lege cloud → alleen lokaal pushen → geen vraag.
      final uid = AuthService.instance.uid;
      if (uid != null) {
        InitialSyncStrategy strategy = InitialSyncStrategy.merge;
        if (_mode == AuthMode.signIn) {
          final hasLocal = await SyncService.instance.localHasData();
          final hasRemote = await SyncService.instance.remoteHasData(uid);
          if (hasLocal && hasRemote && mounted) {
            final chosen = await _showStrategyDialog(context);
            if (chosen == null) {
              // Gebruiker heeft geannuleerd — opnieuw uitloggen zodat er geen
              // half-uitgevoerde status achterblijft.
              await AuthService.instance.signOut();
              if (!mounted) return;
              setState(() => _isSubmitting = false);
              return;
            }
            strategy = chosen;
          }
        }
        await SyncService.instance.syncNow(strategy: strategy);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _humanReadableError(e));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      SyncService.instance.resumeAutoSync();
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Vertaaltabel van Firebase-foutcodes naar leesbare Nederlandse meldingen.
  static const _firebaseErrors = {
    'invalid-email': 'Ongeldig e-mailadres.',
    'user-disabled': 'Dit account is uitgeschakeld.',
    'user-not-found': 'E-mailadres of wachtwoord klopt niet.',
    'invalid-credential': 'E-mailadres of wachtwoord klopt niet.',
    'wrong-password': 'E-mailadres of wachtwoord klopt niet.',
    'email-already-in-use': 'Er bestaat al een account met dit e-mailadres.',
    'weak-password': 'Kies een sterker wachtwoord.',
    'network-request-failed': 'Geen internetverbinding.',
  };

  /// Vertaalt een Firebase-foutcode naar een leesbare Nederlandse foutmelding.
  String _humanReadableError(FirebaseAuthException e) =>
      _firebaseErrors[e.code] ?? e.message ?? 'Er is iets misgegaan.';

  @override
  Widget build(BuildContext context) {
    final isSignIn = _mode == AuthMode.signIn;
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
          isSignIn ? 'Aanmelden' : 'Account aanmaken',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModeSwitcher(),
              const SizedBox(height: 24),
              Text(
                'Synchroniseer je collectie veilig met de cloud. Je gegevens '
                'blijven ook lokaal beschikbaar wanneer je offline bent.',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: AppTheme.gray700,
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildField(
                      controller: _emailCtrl,
                      hint: 'E-mailadres',
                      icon: LucideIcons.mail,
                      keyboard: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(
                        context,
                      ).requestFocus(_passwordFocusNode),
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isEmpty) return 'Vul je e-mailadres in.';
                        final emailRegex = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        );
                        if (!emailRegex.hasMatch(val)) {
                          return 'Ongeldig e-mailadres.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _passwordCtrl,
                      hint: 'Wachtwoord',
                      icon: LucideIcons.lock,
                      obscure: _obscure,
                      focusNode: _passwordFocusNode,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) {
                        final val = v ?? '';
                        if (val.isEmpty) return 'Vul je wachtwoord in.';
                        if (val.length < 6) {
                          return 'Wachtwoord moet minstens 6 tekens bevatten.';
                        }
                        return null;
                      },
                      suffix: IconButton(
                        splashRadius: 18,
                        icon: Icon(
                          _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                          size: 18,
                          color: AppTheme.gray500,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    color: Color(0xFFB84C00),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.orange500,
                          ),
                        )
                      : Icon(
                          isSignIn ? LucideIcons.logIn : LucideIcons.userPlus,
                          size: 20,
                        ),
                  label: Text(
                    isSignIn ? 'Aanmelden' : 'Account aanmaken',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.orange500,
                    side: const BorderSide(color: AppTheme.orange500, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (isSignIn) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _sendPasswordReset(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.gray700,
                  ),
                  child: const Text('Wachtwoord vergeten?'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Stuurt een wachtwoord-resetmail naar het ingevulde e-mailadres.
  Future<void> _sendPasswordReset(BuildContext context) async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Vul je e-mailadres in om te resetten.');
      return;
    }
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Resetlink verzonden. Bekijk je inbox.'),
          ),
        );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _humanReadableError(e));
    }
  }

  /// Bouwt de tabkiezer om te schakelen tussen aanmelden en registreren.
  Widget _buildModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.orange50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(child: _buildModeTab('Aanmelden', AuthMode.signIn)),
          Expanded(child: _buildModeTab('Registreren', AuthMode.register)),
        ],
      ),
    );
  }

  /// Bouwt een individueel tabblad in de moduskiezer.
  Widget _buildModeTab(String label, AuthMode mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _mode = mode;
        _error = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.orange500 : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.white : AppTheme.gray700,
          ),
        ),
      ),
    );
  }

  /// Bouwt een formulierveld met icoon, validator en optioneel achtervoegsel.
  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboard,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboard,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      autocorrect: false,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      style: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 16,
        color: AppTheme.black,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 16,
          color: AppTheme.gray500,
        ),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.orange500),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppTheme.orange50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppTheme.orange500, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Color(0xFFB84C00), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Color(0xFFB84C00), width: 1.5),
        ),
        errorStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          color: Color(0xFFB84C00),
        ),
      ),
    );
  }
}

// ── Strategiedialoog ─────────────────────────────────────────────────────────────

/// Toont een dialoog om de initiële synchronisatiestrategie te kiezen na aanmelding.
Future<InitialSyncStrategy?> _showStrategyDialog(BuildContext context) {
  return showDialog<InitialSyncStrategy>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Gegevens samenvoegen',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.black,
          ),
        ),
        content: Text(
          'Je hebt zowel lokaal als in de cloud al gegevens. Hoe wil je '
          'deze combineren?',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: AppTheme.gray700,
          ),
        ),
        actionsAlignment: MainAxisAlignment.start,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          _StrategyAction(
            icon: LucideIcons.cloudUpload,
            title: 'Lokale gegevens behouden',
            subtitle: 'Cloud wordt overschreven met dit toestel.',
            onTap: () =>
                Navigator.of(ctx).pop(InitialSyncStrategy.overwriteCloud),
          ),
          _StrategyAction(
            icon: LucideIcons.cloudDownload,
            title: 'Cloud gegevens behouden',
            subtitle: 'Lokaal wordt overschreven met de cloud.',
            onTap: () =>
                Navigator.of(ctx).pop(InitialSyncStrategy.overwriteLocal),
          ),
          _StrategyAction(
            icon: LucideIcons.merge,
            title: 'Samenvoegen',
            subtitle: 'Per item wint de meest recente wijziging.',
            onTap: () => Navigator.of(ctx).pop(InitialSyncStrategy.merge),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(foregroundColor: AppTheme.gray700),
              child: const Text('Annuleren'),
            ),
          ),
        ],
      );
    },
  );
}

/// Weergave-widget voor een keuze in het synchronisatiestrategiedialoog.
class _StrategyAction extends StatelessWidget {
  const _StrategyAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.orange50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppTheme.orange500),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
            Icon(LucideIcons.chevronRight, size: 16, color: AppTheme.gray300),
          ],
        ),
      ),
    );
  }
}
