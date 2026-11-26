class AppDimens {
  // 4-pt Spacing Grid
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Corner Radii (Spec: 20 for cards, 999 for pills)
  static const double radiusSm = 8.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 20.0; // Standard Card Radius
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0; // Pill Radius

  // Glassmorphism
  static const double blurSigma = 24.0;

  // Standard Motion Durations
  static const Duration motionFast = Duration(milliseconds: 200); // 200ms ease-out
  static const Duration emojiBurstDuration = Duration(milliseconds: 1200); // 1.2s
  static const Duration eqLoopDuration = Duration(milliseconds: 600); // 600ms loop
}
