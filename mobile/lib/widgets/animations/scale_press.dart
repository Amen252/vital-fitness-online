import 'package:flutter/material.dart';
import 'app_motion.dart';

/// Subtle scale-down on press for buttons and tappable cards.
class ScalePress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;

  const ScalePress({
    super.key,
    required this.child,
    this.onTap,
    this.scale = AppMotion.cardScalePressed,
    this.duration = AppMotion.fast,
  });

  @override
  State<ScalePress> createState() => _ScalePressState();
}

class _ScalePressState extends State<ScalePress> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: widget.duration,
        curve: AppMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}
