import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Notification bell with periodic subtle shake to draw attention.
class ShakeNotificationBell extends StatefulWidget {
  final VoidCallback? onTap;
  final String heroTag;
  final bool hasUnread;
  final Color iconColor;
  final Color backgroundColor;

  const ShakeNotificationBell({
    super.key,
    required this.onTap,
    this.heroTag = 'notification_bell',
    this.hasUnread = false,
    this.iconColor = Colors.white,
    this.backgroundColor = const Color(0x26FFFFFF),
  });

  @override
  State<ShakeNotificationBell> createState() => _ShakeNotificationBellState();
}

class _ShakeNotificationBellState extends State<ShakeNotificationBell> {
  int _shakeKey = 0;

  @override
  void didUpdateWidget(ShakeNotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.hasUnread && widget.hasUnread) {
      setState(() => _shakeKey++);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget bell = Hero(
      tag: widget.heroTag,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_rounded, color: widget.iconColor, size: 20),
              if (widget.hasUnread)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B6B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (widget.hasUnread) {
      bell = bell
          .animate(key: ValueKey(_shakeKey))
          .shake(hz: 3, rotation: 0.04, duration: 600.ms, curve: Curves.easeInOut);
    }

    return GestureDetector(onTap: widget.onTap, child: bell);
  }
}
