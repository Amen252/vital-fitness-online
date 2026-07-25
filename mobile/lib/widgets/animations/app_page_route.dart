import 'package:flutter/material.dart';
import 'app_motion.dart';

/// Fade + subtle slide page transition for premium navigation.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required Widget page,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) : super(
          settings: settings,
          fullscreenDialog: fullscreenDialog,
          transitionDuration: AppMotion.page,
          reverseTransitionDuration: AppMotion.normal,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: AppMotion.easeOut);
            final slide = Tween<Offset>(
              begin: const Offset(0, AppMotion.slideOffset),
              end: Offset.zero,
            ).animate(curved);

            return FadeTransition(
              opacity: curved,
              child: SlideTransition(position: slide, child: child),
            );
          },
        );
}

/// Global page transition builder for [ThemeData.pageTransitionsTheme].
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, AppMotion.slideOffset),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
