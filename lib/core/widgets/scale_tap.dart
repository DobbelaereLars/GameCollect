import 'package:flutter/widgets.dart';

/// Gedeeld tik-widget met een veer-animatie (schaal 0.94) bij aanraking.
///
/// Ondersteunt optioneel een long-press die de ingedrukte staat vasthoudt
/// totdat de bijbehorende [Future] voltooid is (bijv. totdat een bottom
/// sheet gesloten is).
class ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// Async callback voor long press. De schaalanimatie blijft actief totdat
  /// de Future voltooid is.
  final Future<void> Function()? onLongPress;

  const ScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> {
  bool _pressed = false;

  Future<void> _handleLongPress() async {
    if (!mounted) return;
    setState(() => _pressed = true);
    try {
      await widget.onLongPress?.call();
    } finally {
      if (mounted) setState(() => _pressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress != null ? _handleLongPress : null,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
