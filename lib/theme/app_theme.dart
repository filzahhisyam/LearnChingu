import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand
  static const primary = Color(0xFF88A2FF); // pastel blue
  static const primaryDark = Color(0xFF253A82); // deep royal blue
  static const primaryLight = Color(0xFFC0E0FF); // light blue
  static const primarySurface = Color(0xFFEAF1FF);

  // Accent (success / adaptive correct)
  static const green = Color(0xFFE3FC87);
  static const greenDark = Color(0xFF2D7A50);
  static const greenSurface = Color(0xFFF0FAF5);

  // Accent (info / AI insight)
  static const purple = Color(0xFFAB9DFF);
  static const purpleSurface = Color(0xFFEEEDFE);

  // Pink Accent
  static const pink = Color(0xFFFFB2F7);
  static const pinkSurface = Color(0xFFFFEEFD);

  // Neutral
  static const background = Color.fromARGB(255, 252, 252, 252);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color.fromARGB(255, 223, 221, 219);
  static const textPrimary = Color(0xFF1E1E1E);
  static const textSecondary = Color(0xFF5A5A5A);
  static const textHint = Color(0xFFBDBDBD);
}

class AppAssets {
  // Define the path to your custom avatar PNG
  static const String chinguIcon = 'assets/images/1.png';
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.green,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.baloo2(
          fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
        ),
        displayMedium: GoogleFonts.baloo2(
          fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
        ),
        displaySmall: GoogleFonts.baloo2(
          fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.baloo2(
          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
        ),
        labelLarge: GoogleFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.primaryDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.outfit(color: AppColors.textHint, fontSize: 14),
        labelStyle: GoogleFonts.outfit(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1.5),
        ),
      ),
    );
  }
}
