import 'package:flutter/material.dart';

/// Shared colors, decorations, and shell widgets for the coach dashboard.
class CoachDashboardTheme {
  static const Color primary = Color(0xFF3D4F9F);
  static const Color primaryLight = Color(0xFF5B6FD6);
  static const Color accent = Color(0xFF0EA5E9);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color pink = Color(0xFFDB2777);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF2E3A6B), Color(0xFF3D4F9F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color homeBackground(bool isDark) =>
      isDark ? const Color(0xFF0F1117) : const Color(0xFFF3F4F8);

  static Color navBarBackground(bool isDark) =>
      isDark ? const Color(0xFF181B24) : Colors.white;

  static Color drawerBackground(bool isDark) =>
      isDark ? const Color(0xFF181B24) : Colors.white;

  static Color shellBorder(bool isDark) =>
      isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB);

  static BoxDecoration cardDecoration(bool isDark) => BoxDecoration(
        color: isDark ? const Color(0xFF181B24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      );

  static TextStyle appBarTitle(bool isDark) => TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 17,
        letterSpacing: -0.2,
        color: isDark ? Colors.white : textPrimary,
      );

  static TextStyle sectionTitle(bool isDark) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : textPrimary,
        letterSpacing: -0.2,
      );

  static TextStyle sectionLabel(bool isDark) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: isDark ? Colors.white38 : textSecondary,
      );

  /// Large heading shown on gradient headers (white text by default).
  static TextStyle displayTitle({double fontSize = 28, Color color = Colors.white}) => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.5,
        color: color,
      );

  /// Greeting line shown on gradient headers.
  static TextStyle greetingText(bool isDark) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.white.withValues(alpha: 0.9),
      );

  /// Muted body text for cards and subtitles.
  static TextStyle bodyMuted(bool isDark) => TextStyle(
        fontSize: 14,
        height: 1.4,
        color: isDark ? Colors.white60 : textSecondary,
      );

  static TextStyle metricValue(Color color) => TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
        height: 1,
      );

  static TextStyle metricLabel(bool isDark) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white60 : textSecondary,
      );

  static PreferredSizeWidget coachAppBar({
    required BuildContext context,
    required String title,
    List<Widget>? actions,
    bool centerTitle = true,
    PreferredSizeWidget? bottom,
    Widget? leading,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      title: Text(title, style: appBarTitle(isDark)),
      backgroundColor: homeBackground(isDark),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      leading: leading ?? dashboardLeading(context),
      actions: actions,
      bottom: bottom,
    );
  }

  static InputDecoration searchDecoration({required bool isDark, required String hint}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white38 : textSecondary),
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? Colors.white54 : textSecondary),
        filled: true,
        fillColor: isDark ? const Color(0xFF181B24) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      );

  static Widget filterChip({
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primary : (isDark ? const Color(0xFF181B24) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? primary : (isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : (isDark ? Colors.white70 : textSecondary),
          ),
        ),
      ),
    );
  }

  static Widget emptyState({
    required IconData icon,
    required String message,
    required bool isDark,
    String? title,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: isDark ? Colors.white24 : textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            if (title != null && title.trim().isNotEmpty) ...[
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : textPrimary,
                ),
              ),
              const SizedBox(height: 8),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? Colors.white54 : textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static InputDecoration fieldDecoration({
    required bool isDark,
    required String label,
    String? hint,
    IconData? prefixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB)),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: isDark ? Colors.white54 : textSecondary, fontSize: 13),
      hintStyle: TextStyle(color: isDark ? Colors.white38 : textSecondary.withValues(alpha: 0.7)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: isDark ? Colors.white54 : textSecondary) : null,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF9FAFB),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  static ButtonStyle primaryButtonStyle() => ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      );

  static Widget avatarBox({required String initial, Color? color, double size = 44}) {
    final c = color ?? primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: size * 0.38),
      ),
    );
  }

  /// Back button when pushed onto the stack; menu button on main bottom-nav tabs.
  static Widget dashboardLeading(BuildContext context) {
    if (Navigator.canPop(context)) {
      return IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => Navigator.of(context).pop(),
      );
    }
    return Builder(
      builder: (ctx) => IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () {
          final scaffold = Scaffold.maybeOf(ctx);
          if (scaffold?.hasDrawer ?? false) {
            scaffold!.openDrawer();
          } else {
            Scaffold.of(context).openDrawer();
          }
        },
      ),
    );
  }
}

/// Standard coach screen shell with consistent background and app bar.
class CoachPage extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  const CoachPage({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: CoachDashboardTheme.coachAppBar(
        context: context,
        title: title,
        actions: actions,
        centerTitle: centerTitle,
        bottom: bottom,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
