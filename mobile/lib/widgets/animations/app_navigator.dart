import 'package:flutter/material.dart';
import 'app_page_route.dart';

/// Central navigation helper with premium transitions + hero support.
abstract final class AppNavigator {
  static Future<T?> push<T>(BuildContext context, Widget page, {bool fullscreen = false}) {
    return Navigator.of(context).push<T>(
      AppPageRoute<T>(page: page, fullscreenDialog: fullscreen),
    );
  }

  static Future<T?> pushReplacement<T, TO>(BuildContext context, Widget page) {
    return Navigator.of(context).pushReplacement<T, TO>(
      AppPageRoute<T>(page: page),
    );
  }

  static Future<T?> pushAndRemoveUntil<T>(
    BuildContext context,
    Widget page,
    bool Function(Route<dynamic>) predicate,
  ) {
    return Navigator.of(context).pushAndRemoveUntil<T>(
      AppPageRoute<T>(page: page),
      predicate,
    );
  }
}
