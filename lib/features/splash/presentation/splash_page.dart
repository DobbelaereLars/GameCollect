import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../../navigation/presentation/game_collect_shell.dart';

/// Opstartscherm dat kort getoond wordt bij het openen van de app.
/// Toont het gamepad-icoon met een bounce-animatie, gevolgd door
/// een uitvergroot masker dat het hoofdscherm onthult.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  /// Bestuurt de bounce-animatie waarmee het icoon verschijnt.
  late final AnimationController _bounceCtrl;

  /// Schaalwaarde van de bounce: 0.0 → 1.0 met easeOutBack (licht overshoot).
  late final Animation<double> _bounceScale;

  /// Doorzichtigheid van het icoon tijdens de bounce-animatie.
  late final Animation<double> _bounceOpacity;

  /// Bestuurt de uitvergrotings-animatie nadat de bounce klaar is.
  late final AnimationController _zoomCtrl;

  /// Schaalwaarde van het icoon tijdens het uitvergroten (1.0 → 24.0).
  late final Animation<double> _zoomScale;

  /// Geeft aan of de uitvergroting bezig is (schakelt bounce naar zoom).
  bool _zooming = false;

  /// Weergavegrootte van het icoon – bepaalt de startafmeting van het clipper-masker.
  static const double _iconSize = 64.0;

  @override
  void initState() {
    super.initState();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _bounceScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOutBack));
    _bounceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _bounceCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _zoomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _zoomScale = Tween<double>(
      begin: 1.0,
      end: 24.0,
    ).animate(CurvedAnimation(parent: _zoomCtrl, curve: Curves.easeIn));

    _run();
  }

  /// Voert de volledige opstartanimatie uit en navigeert daarna naar de app.
  ///
  /// Fase 1 – Bounce: het icoon springt in beeld met een lichte overshoot.
  /// Fase 2 – Zoom: het icoon vergroot naar 24× terwijl een afgerond vierkant
  /// masker vanuit het midden groeit en het hoofdscherm onthult.
  Future<void> _run() async {
    await _bounceCtrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;

    final s = MediaQuery.of(context).size;
    final center = Offset(s.width / 2, s.height / 2);
    final brightness = AppThemeController.instance.effectiveBrightness;

    // Diagonaal van het scherm – garandeert dat het masker elke hoek bedekt.
    final diagonal = sqrt(s.width * s.width + s.height * s.height);

    _zoomCtrl.forward();
    if (mounted) setState(() => _zooming = true);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) =>
            GameCollectShell(key: ValueKey(brightness)),
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (_, animation, __, child) {
          return AnimatedBuilder(
            animation: animation,
            builder: (_, __) {
              final t = Curves.easeIn.transform(animation.value);
              // Groei van icoongrootte naar 2× diagonaal zodat het scherm altijd volledig bedekt is.
              final side = lerpDouble(_iconSize, diagonal * 2, t)!;
              // Hoekradius proportioneel: begint overeenkomend met het icoon (~1/5 van grootte),
              // schaalt mee zodat de afgeronde-vierkantvorm behouden blijft.
              final radius =
                  (_iconSize / 5) * (_iconSize / side).clamp(0.0, 1.0);
              return ClipPath(
                clipper: _RoundedSquareClipper(
                  side: side,
                  center: center,
                  borderRadius: radius,
                ),
                child: child,
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _zoomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_bounceCtrl, _zoomCtrl]),
          builder: (_, __) => Opacity(
            opacity: _zooming ? 1.0 : _bounceOpacity.value,
            child: Transform.scale(
              scale: _zooming ? _zoomScale.value : _bounceScale.value,
              child: const Icon(
                LucideIcons.gamepad2,
                size: _iconSize,
                color: AppTheme.orange500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Knipt de child tot een afgerond vierkant gecentreerd op [center].
/// Op icoongrootte komen de hoeken overeen met de gamepad-vorm;
/// naarmate het masker groeit blijft de proportionele radius consistent
/// totdat het vierkant groot genoeg is om het volledige scherm te bedekken.
class _RoundedSquareClipper extends CustomClipper<Path> {
  final double side;
  final Offset center;
  final double borderRadius;

  const _RoundedSquareClipper({
    required this.side,
    required this.center,
    required this.borderRadius,
  });

  @override
  Path getClip(Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: side, height: side),
      Radius.circular(borderRadius),
    );
    return Path()..addRRect(rrect);
  }

  @override
  bool shouldReclip(_RoundedSquareClipper old) =>
      old.side != side || old.borderRadius != borderRadius;
}
