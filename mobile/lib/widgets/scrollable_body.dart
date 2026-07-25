import 'package:flutter/material.dart';

/// Consistent scroll physics for dashboard tabs (always allows vertical drag).
const ScrollPhysics dashboardScrollPhysics = AlwaysScrollableScrollPhysics();

/// Vertically scrollable wrapper for tab content and static pages.
class ScrollableBody extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final bool primary;

  const ScrollableBody({
    super.key,
    required this.child,
    this.padding,
    this.controller,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: controller,
          primary: primary,
          physics: dashboardScrollPhysics,
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// Centers content inside a scrollable area (loading, errors, empty states).
class ScrollableCenter extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const ScrollableCenter({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollableBody(
      padding: padding ?? const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Center(child: child),
    );
  }
}
