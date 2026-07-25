import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'app_motion.dart';

/// Entrance animation for dashboard cards and list tiles.
class PremiumCard extends StatelessWidget {
  final Widget child;
  final int index;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const PremiumCard({
    super.key,
    required this.child,
    this.index = 0,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final delay = (index * 45).ms;
    Widget content = child;
    if (margin != null) {
      content = Padding(padding: margin!, child: child);
    }

    content = content
        .animate(delay: delay)
        .fadeIn(duration: AppMotion.normal, curve: AppMotion.easeOut)
        .slideY(begin: AppMotion.slideOffset, end: 0, duration: AppMotion.normal, curve: AppMotion.easeOut);

    if (onTap != null) {
      return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: content);
    }
    return content;
  }
}

/// Stagger helper — wrap list children with index-based entrance.
extension StaggerAnimate on Widget {
  Widget staggerIn(int index, {Duration? delayPerItem}) {
    final step = delayPerItem ?? const Duration(milliseconds: 45);
    return animate(delay: step * index)
        .fadeIn(duration: AppMotion.normal, curve: AppMotion.easeOut)
        .slideY(begin: AppMotion.slideOffset * 0.8, end: 0, duration: AppMotion.normal, curve: AppMotion.easeOut);
  }
}
