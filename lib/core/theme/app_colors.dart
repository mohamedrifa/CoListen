import 'package:flutter/material.dart';

class AppColors {
  // Midnight Studio Canvas & Surfaces
  static const Color background = Color(0xFF0D0D12);
  static const Color surface = Color(0xFF161622);
  static const Color surfaceCard = Color(0xFF161622);
  static const Color surfaceHighlight = Color(0xFF1E1E2E); // Inputs, chips, elevated tiles
  static const Color surfaceLight = Color(0xFF1E1E2E);

  // Accents & Brand Gradients
  static const Color primary = Color(0xFF7C4DFF); // Electric Royal Violet
  static const Color primaryLight = Color(0xFFB388FF);
  static const Color primaryDark = Color(0xFF512DA8);

  static const Color secondary = Color(0xFF00E5FF); // Neon Cyan (Active Sync & Highlights)
  static const Color accent = Color(0xFF00E5FF);
  static const Color livePulse = Color(0xFFF43F5E); // Live indicator / Hot reactions

  // Status Colors
  static const Color success = Color(0xFF00E676); // Mint Green
  static const Color warning = Color(0xFFFFD600); // Electric Amber
  static const Color error = Color(0xFFFF1744); // Crimson

  // Typography Tokens
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A0B8);
  static const Color textMuted = Color(0xFF62627A);

  // Glassmorphic Overlays & Borders
  static const Color glassFill = Color(0xCC161622);
  static const Color glassBorder = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)

  // Primary Brand Gradient (#7C4DFF -> #00E5FF)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Ambient Glow Gradients
  static const RadialGradient heroGlow = RadialGradient(
    colors: [
      Color(0x337C4DFF),
      Color(0x0A00E5FF),
      Colors.transparent,
    ],
    radius: 0.8,
  );
}
