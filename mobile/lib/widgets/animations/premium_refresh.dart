import 'package:flutter/material.dart';
import 'app_motion.dart';

/// Pull-to-refresh without any spinner chrome.
class PremiumRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;

  const PremiumRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Colors.transparent,
      backgroundColor: Colors.transparent,
      strokeWidth: 0.0001,
      displacement: 0,
      elevation: 0,
      child: child,
    );
  }
}

class AnimatedContentSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const AnimatedContentSwitcher({
    super.key,
    required this.child,
    this.duration = AppMotion.normal,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.easeOut,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
