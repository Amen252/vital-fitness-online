import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual tokens matching the premium auth landing reference.
abstract final class AuthLandingTheme {
  static const Color background = Color(0xFF000000);
  static const Color primaryCta = Color(0xFF00B89E);
  static const Color primaryCtaText = Color(0xFF121212);
  static const Color subtitle = Color(0xFFB8B8B8);
  static const Color footer = Color(0xFF8E8E8E);
  static const Color outline = Color(0xFFE8E8E8);
  static const Color fieldFill = Color(0xFF1C1C1C);
  static const Color fieldBorder = Color(0xFF3A3A3A);

  static const double horizontalPadding = 24;
  static const double buttonHeight = 54;
  static const double buttonRadius = 999;
  static const double tileRadius = 12;
  static const double tileGap = 6;

  static TextStyle get headline => GoogleFonts.playfairDisplay(
        fontSize: 38,
        fontWeight: FontWeight.w600,
        height: 1.18,
        color: Colors.white,
        letterSpacing: -0.3,
      );

  static TextStyle get subheadline => const TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: subtitle,
      );

  static TextStyle get buttonLabel => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      );

  static TextStyle get footerStyle => const TextStyle(
        fontSize: 13,
        height: 1.35,
        color: footer,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get formTitle => GoogleFonts.playfairDisplay(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.15,
      );

  static TextStyle get formSubtitle => const TextStyle(
        fontSize: 15,
        height: 1.4,
        color: subtitle,
      );
}
