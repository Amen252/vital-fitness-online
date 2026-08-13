import 'package:flutter/material.dart';

/// RefreshIndicator with zero visible loading chrome.
class SilentRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;

  const SilentRefreshIndicator({
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
