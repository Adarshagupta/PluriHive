import 'package:flutter/material.dart';

/// Design system constants for consistent UI across the app
class AppConstants {
  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  
  // Border Radius
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 24.0;
  
  // Card Elevation
  static const double elevationNone = 0.0;
  static const double elevationSm = 2.0;
  static const double elevationMd = 4.0;
  
  // Icon Sizes
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  
  // App Bar Heights
  static const double appBarExpandedHeight = 200.0;
  static const double appBarCollapsedHeight = kToolbarHeight;
}

/// Consistent gradient backgrounds
class AppGradients {
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF8F0),
      Color(0xFFFFF5E9),
      Color(0xFFFFF0DC),
    ],
  );
  
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7FE87A),
      Color(0xFF6FD866),
    ],
  );
  
  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF9D7BEA),
      Color(0xFF7E5FD8),
    ],
  );
}
