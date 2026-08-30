import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF5F6FA);
  static const surface = Colors.white;
  static const ink = Color(0xFF101828);
  static const muted = Color(0xFF667085);
  static const navy = Color(0xFF0F1B33);
  static const navySoft = Color(0xFF1E315B);
  static const gold = Color(0xFFE2B11F);
  static const goldDark = Color(0xFFC79400);
  static const goldSoft = Color(0xFFFFF3C4);
  static const border = Color(0xFFE6E8EE);
  static const success = Color(0xFF17854B);
  static const danger = Color(0xFFD92D20);
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.light,
      surface: AppColors.surface,
    ).copyWith(
      primary: AppColors.navy,
      secondary: AppColors.gold,
      onPrimary: Colors.white,
      onSecondary: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      splashColor: AppColors.gold.withValues(alpha: .08),
      highlightColor: AppColors.gold.withValues(alpha: .04),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.08, color: AppColors.ink),
        headlineMedium: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, height: 1.12, color: AppColors.ink),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.ink),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
        bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: AppColors.ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: AppColors.muted),
        labelLarge: TextStyle(fontWeight: FontWeight.w800),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.ink,
        titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: Color(0xFF98A2B3)),
        labelStyle: const TextStyle(color: AppColors.muted),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.goldDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.goldSoft,
        elevation: 12,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? AppColors.ink : AppColors.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.navy : AppColors.muted,
            size: 24,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.goldSoft,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
