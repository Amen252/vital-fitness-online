import 'package:flutter/animation.dart';

/// Shared motion tokens — tuned for 60 FPS, snappy but premium feel.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration page = Duration(milliseconds: 320);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve spring = Curves.easeOutBack;

  static const double slideOffset = 0.06;
  static const double cardScalePressed = 0.97;
  static const double navIconScale = 1.12;
}
