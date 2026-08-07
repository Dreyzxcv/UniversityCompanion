import 'package:flutter/material.dart';

/// Central design tokens matching the ALON-style visual language: deep
/// navy hero cards, soft lavender background, rounded everything.
class AppColors {
  AppColors._();

  static const navyDark = Color(0xFF161F5B);
  static const navyMid = Color(0xFF29357F);
  static const background = Color(0xFFF2F3FB);
  static const textDark = Color(0xFF14163A);
  static const textMuted = Color(0xFF6B7099);
  static const pillLavender = Color(0xFFE9EBFB);
  static const mint = Color(0xFFE1F5F0);
  static const overdue = Color(0xFFE0483E);
  static const cardBorder = Color(0xFFE7E8F5);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDark, navyMid],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get themeData {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.navyDark,
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.navyDark,
        surface: Colors.white,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.pillLavender.withOpacity(0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navyDark,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navyDark,
          side: const BorderSide(color: AppColors.navyDark, width: 1.4),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
      ),
    );
  }
}