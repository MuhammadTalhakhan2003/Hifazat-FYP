import 'package:flutter/material.dart';

class AppColors {
  // Primary brand colors for the light theme
  static const Color primaryBlue = Color(0xFF0F3460);     // A strong, deep blue
  static const Color accentPurple = Color(0xFF533483);    // A vibrant purple for highlights
  static const Color highlightBlue = Color(0xFF5089C6);    // A brighter, friendly blue

  // Text and background colors
  static const Color backgroundLight = Color(0xFFF5F5F7); // Off-white for background
  static const Color surfaceLight = Colors.white;          // Pure white for cards
  static const Color textDark = Color(0xFF1D1D1F);        // Primary text color (dark grey)
  static const Color textGrey = Colors.black54;          // Secondary text
  static const Color border = Color(0xFFE6E8EE);         // Card/divider outline

  // Status colors
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);

  // Gradient used for screen headers (Profile, Incidents feed, ...)
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, accentPurple],
  );

  // You can still keep the old MaterialColor if needed elsewhere.
  static const MaterialColor primaryMaterialColor = MaterialColor(
    0xFF0F3460, // The primary value
    <int, Color>{
      50: Color(0xFFE2E7EC),
      100: Color(0xFFB6C3D2),
      200: Color(0xFF869CB6),
      300: Color(0xFF56749A),
      400: Color(0xFF325785),
      500: Color(0xFF0F3460),
      600: Color(0xFF0D2F58),
      700: Color(0xFF0B294E),
      800: Color(0xFF082344),
      900: Color(0xFF041732),
    },
  );
}