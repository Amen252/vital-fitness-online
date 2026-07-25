import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'app_motion.dart';

/// Animated horizontal progress bar for stats and goals.
class AnimatedStatBar extends StatelessWidget {
  final double value;
  final double max;
  final Color color;
  final Color backgroundColor;
  final double height;
  final Duration duration;

  const AnimatedStatBar({
    super.key,
    required this.value,
    this.max = 100,
    required this.color,
    this.backgroundColor = const Color(0xFFE8ECF0),
    this.height = 8,
    this.duration = AppMotion.slow,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: duration,
        curve: AppMotion.easeOut,
        builder: (context, animValue, _) {
          return Stack(
            children: [
              Container(height: height, color: backgroundColor),
              FractionallySizedBox(
                widthFactor: animValue,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.75)]),
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Animated counter text for statistics.
class AnimatedStatValue extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final String suffix;
  final int fractionDigits;

  const AnimatedStatValue({
    super.key,
    required this.value,
    this.style,
    this.suffix = '',
    this.fractionDigits = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: AppMotion.slow,
      curve: AppMotion.easeOut,
      builder: (context, anim, _) {
        final text = fractionDigits > 0
            ? anim.toStringAsFixed(fractionDigits)
            : anim.round().toString();
        return Text('$text$suffix', style: style);
      },
    ).animate().fadeIn(duration: AppMotion.normal);
  }
}
