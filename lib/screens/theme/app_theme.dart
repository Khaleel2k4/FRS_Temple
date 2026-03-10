import 'package:flutter/material.dart';

class AppTheme {
  static const Color deepSaffron = Color(0xFFFF8F00);
  static const Color richGold = Color(0xFFFFD27D);
  static const Color ivory = Color(0xFFFFF8E7);
  static const Color sandalwood = Color(0xFFD9C6A5);
  static const Color templeBrown = Color(0xFF4E342E);

  static ThemeData get theme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: deepSaffron,
      brightness: Brightness.light,
    ).copyWith(
      primary: deepSaffron,
      secondary: richGold,
      surface: Colors.white,
      background: ivory,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ivory,
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.68),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: sandalwood.withOpacity(0.38)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: sandalwood.withOpacity(0.38)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: deepSaffron, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: templeBrown,
          letterSpacing: 0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: templeBrown,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: templeBrown,
        ),
      ),
    );
  }
}
