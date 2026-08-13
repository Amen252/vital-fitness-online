import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../screens/dashboard/widgets/coach_home/coach_dashboard_theme.dart';

/// Shared load/refresh state for dashboard tabs (no loading UI).
mixin TabRefreshMixin<T extends StatefulWidget> on State<T> {
  bool tabIsLoading = true;
  bool tabIsRefreshing = false;
  bool tabHasLoadedOnce = false;
  String? tabLoadError;

  /// Never gate the UI on a loading screen.
  bool get showInitialLoading => false;
  bool get showInitialError => tabLoadError != null && !tabHasLoadedOnce;

  void beginTabLoad({required bool isRefresh}) {
    setState(() {
      if (!isRefresh && !tabHasLoadedOnce) {
        tabIsLoading = true;
        tabLoadError = null;
      } else if (isRefresh) {
        tabIsRefreshing = true;
        tabLoadError = null;
      }
    });
  }

  void finishTabLoad(VoidCallback applyData) {
    if (!mounted) return;
    setState(() {
      applyData();
      tabIsLoading = false;
      tabIsRefreshing = false;
      tabHasLoadedOnce = true;
      tabLoadError = null;
    });
  }

  String? finishTabError(Object error, {bool isRefresh = false, bool showSnackBar = false}) {
    if (!mounted) return null;
    final message = ApiService.friendlyError(error);
    if (tabHasLoadedOnce) {
      setState(() {
        tabIsLoading = false;
        tabIsRefreshing = false;
      });
      if (showSnackBar || isRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: CoachDashboardTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return message;
    }
    setState(() {
      tabLoadError = message;
      tabIsLoading = false;
      tabIsRefreshing = false;
      tabHasLoadedOnce = true;
    });
    return null;
  }

  Widget tabRefreshIcon({Color? color, double size = 22}) {
    return Icon(Icons.refresh_rounded, color: color, size: size);
  }
}

Widget refreshableScrollChild({
  required BuildContext context,
  required Widget child,
  EdgeInsetsGeometry? padding,
  bool center = true,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding ?? const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
          ),
          child: center ? Center(child: child) : child,
        ),
      );
    },
  );
}
