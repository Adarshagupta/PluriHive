import 'package:flutter/material.dart';

class AppTheme {
  // Pale-cyan + white unified palette
  static const Color primaryColor = Color(0xFF0E9FA0);
  static const Color secondaryColor = Color(0xFF4A6A6D);
  static const Color accentColor = Color(0xFF0B6F73);
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color darkBackgroundColor = Color(0xFF0B1C1F);
  static const Color cardColor = Color(0xFFF8FEFE);
  static const Color textPrimary = Color(0xFF0B2D30);
  static const Color textSecondary = Color(0xFF4A6A6D);
  static const Color textTertiary = Color(0xFF6B8B8E);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF22C55E);
  static const Color warningColor = Color(0xFFFBBF24);

  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _FadeSlidePageTransitionsBuilder(),
      TargetPlatform.iOS: _FadeSlidePageTransitionsBuilder(),
    },
  );
  
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: _pageTransitionsTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      secondary: secondaryColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimary,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: cardColor,
      shadowColor: Colors.black.withOpacity(0.04),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.04),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: false,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: accentColor, width: 1.5),
      ),
    ),
  );
  
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: _pageTransitionsTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      secondary: secondaryColor,
    ),
    scaffoldBackgroundColor: darkBackgroundColor,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}

class _FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst) {
      return child;
    }

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.06, 0.0),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: FadeTransition(
        opacity: curvedAnimation,
        child: child,
      ),
    );
  }
}
