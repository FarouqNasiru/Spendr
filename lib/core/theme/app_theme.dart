// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_text_styles.dart';

// 1. First, let's define the specific colors used in your designs
class AppColors {
  // The Main Background (Off-White/Light Green tint)
  static const Color background = Color(0xFFF9FBF2);

  // The Brand Lime Green (Buttons, Accents)
  static const Color primary = Color(0xFFE2F163);

  // The Brand Navy (Cards, Text, Dark Backgrounds)
  static const Color secondary = Color(0xFF0D1B2A);

  // A secondary Light Green for category cards
  static const Color cardLight = Color(0xFFEDF2E4);

  static const Color error = Colors.redAccent;
}

class AppTheme {
  /// 🌞 LIGHT THEME
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,

    // Updated AppBar to be Transparent with Dark Icons by default
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent, // Transparent to match designs
      elevation: 0,
      titleTextStyle: AppTextStyles.heading2,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Android: Dark icons
        statusBarBrightness: Brightness.light, // iOS: Dark icons
      ),
      iconTheme: IconThemeData(color: AppColors.secondary), // Navy Icons
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary, // Lime Green FAB
      foregroundColor: Colors.black, // Black icon on Lime
    ),

    textTheme: TextTheme(
      headlineLarge: AppTextStyles.heading1.copyWith(
        color: AppColors.secondary,
      ),
      headlineMedium: AppTextStyles.heading2.copyWith(
        color: AppColors.secondary,
      ),
      bodyMedium: AppTextStyles.body.copyWith(color: AppColors.secondary),
      labelLarge: AppTextStyles.label.copyWith(color: AppColors.secondary),
    ),

    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.black, // Text on Lime button is black
      secondary: AppColors.secondary,
      onSecondary: Colors.white, // Text on Navy card is white
      surface: AppColors.cardLight,
      error: AppColors.error,
    ),
  );

  /// 🌚 DARK THEME
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.secondary, // Navy Background
    primaryColor: AppColors.primary,

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Android: White icons
        statusBarBrightness: Brightness.dark, // iOS: White icons
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary, // Keep Lime for contrast
      foregroundColor: Colors.black,
    ),

    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      bodyMedium: TextStyle(fontSize: 16, color: Colors.white70),
    ),

    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.black,
      secondary: AppColors.secondary,
      surface: Color(
        0xFF1E2D3D,
      ), // Slightly lighter Navy for cards in Dark Mode
      error: AppColors.error,
    ),
  );
}
