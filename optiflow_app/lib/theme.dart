import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand Colors (OptiFlow Command Design System) ──
  static const Color primary        = Color(0xFF0052D4);
  static const Color primaryDark    = Color(0xFF003DA2);
  static const Color primaryLight   = Color(0xFFB3C5FF);
  static const Color background     = Color(0xFFFAF8FF);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color surfaceContainer = Color(0xFFEDEDF8);
  static const Color surfaceHigh    = Color(0xFFE7E7F2);
  static const Color onSurface      = Color(0xFF191B23);
  static const Color onSurfaceVar   = Color(0xFF434654);
  static const Color outline        = Color(0xFF737686);
  static const Color outlineVar     = Color(0xFFC3C6D7);
  static const Color error          = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color success        = Color(0xFF16A34A);
  static const Color successBg      = Color(0xFFDCFCE7);
  static const Color warning        = Color(0xFFD97706);
  static const Color warningBg      = Color(0xFFFEF3C7);
  static const Color criticalRed    = Color(0xFFDC2626);
  static const Color criticalRedBg  = Color(0xFFFEE2E2);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: onSurface,
        error: error,
      ),
      textTheme: TextTheme(
        // Headlines — Hanken Grotesk
        displayLarge: GoogleFonts.hankenGrotesk(
          fontSize: 32, fontWeight: FontWeight.w700,
          letterSpacing: -0.64, color: onSurface,
        ),
        displayMedium: GoogleFonts.hankenGrotesk(
          fontSize: 28, fontWeight: FontWeight.w700,
          letterSpacing: -0.56, color: onSurface,
        ),
        headlineLarge: GoogleFonts.hankenGrotesk(
          fontSize: 24, fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        headlineMedium: GoogleFonts.hankenGrotesk(
          fontSize: 18, fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        headlineSmall: GoogleFonts.hankenGrotesk(
          fontSize: 16, fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        // Body — Inter
        bodyLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w400,
          color: onSurface,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400,
          color: onSurface,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w400,
          color: onSurfaceVar,
        ),
        // Labels — JetBrains Mono
        labelLarge: GoogleFonts.jetBrainsMono(
          fontSize: 12, fontWeight: FontWeight.w700,
          letterSpacing: 0.6, color: onSurface,
        ),
        labelMedium: GoogleFonts.jetBrainsMono(
          fontSize: 11, fontWeight: FontWeight.w600,
          letterSpacing: 0.55, color: onSurface,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 10, fontWeight: FontWeight.w600,
          letterSpacing: 0.5, color: onSurfaceVar,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: outlineVar,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: primary,
        ),
        iconTheme: const IconThemeData(color: onSurface, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: outlineVar, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: outlineVar),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: outlineVar, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14, color: outline,
        ),
        labelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 11, fontWeight: FontWeight.w700,
          letterSpacing: 0.6, color: onSurfaceVar,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: outlineVar),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w500,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: outline,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: outlineVar, thickness: 0.5, space: 0,
      ),
    );
  }
}
