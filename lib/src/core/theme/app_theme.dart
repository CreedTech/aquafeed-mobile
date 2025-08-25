import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AquaFeed Design System
/// Airbnb-inspired rounded design with light/dark mode support
/// Designed for Nigerian fish farmers - outdoor use, high contrast, large touch targets
class AppTheme {
  // === PRIMARY COLORS ===
  static const Color primary = Color(0xFF0EA27E); // Nice teal green
  static const Color primaryDark = Color(0xFF0A8066); // Darker for contrast
  static const Color primaryLight = Color(0xFF3DBB9A); // Lighter green

  // === NEUTRAL COLORS (Light Mode) ===
  static const Color black = Color(0xFF1A1A1A); // Main text
  static const Color grey600 = Color(0xFF525252); // Secondary text
  static const Color grey400 = Color(0xFF9CA3AF); // Muted text
  static const Color grey200 = Color(0xFFE5E7EB); // Borders
  static const Color grey100 = Color(0xFFF3F4F6); // Card backgrounds
  static const Color white = Color(0xFFFFFFFF);

  // === DARK MODE COLORS ===
  static const Color darkBg = Color(0xFF121212); // Background
  static const Color darkSurface = Color(0xFF1E1E1E); // Card surface
  static const Color darkSurface2 = Color(0xFF2A2A2A); // Elevated surface
  static const Color darkGrey = Color(0xFF404040); // Borders
  static const Color darkTextPrimary = Color(0xFFE5E5E5); // Primary text
  static const Color darkTextSecondary = Color(0xFFA3A3A3); // Secondary text

  // === TOLERANCE COLORS (High Contrast for Outdoor) ===
  static const Color toleranceRed = Color(0xFFDC2626); // Below standard
  static const Color toleranceBlue = Color(0xFF2563EB); // Within tolerance
  static const Color toleranceGreen = Color(0xFF16A34A); // Above standard

  // === SEMANTIC COLORS ===
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // === PREMIUM GRADIENTS ===
  static const List<Color> primaryGradient = [
    Color(0xFF0EA27E),
    Color(0xFF3DBB9A),
  ];
  static const List<Color> darkGradient = [
    Color(0xFF1A1A1A),
    Color(0xFF2D2D2D),
  ];
  static const List<Color> blueGradient = [
    Color(0xFF2563EB),
    Color(0xFF3B82F6),
  ];
  static const List<Color> amberGradient = [
    Color(0xFFD97706),
    Color(0xFFF59E0B),
  ];

  // === PREMIUM SHADOWS ===
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> tightShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> premiumShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 24,
      spreadRadius: 0,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      blurRadius: 8,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
  );

  // === LEGACY ALIASES (backward compatibility) ===
  static const Color primaryGreen = primary;
  static const Color accentGreen = success;
  static const Color backgroundLight = white;
  static const Color textMain = black;
  static const Color cardSurface = white;
  static const Color errorRed = error;
  static const Color accentLime = Color(0xFFD4E157);

  // === SPACING (Touch-friendly) ===
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacing2xl = 48;

  // === RADIUS (Airbnb-style, very rounded) ===
  static const double radiusSm = 16;
  static const double radiusMd = 20;
  static const double radiusLg = 24;
  static const double radiusXl = 32;
  static const double radiusFull = 100; // Pills and circles

  // === MINIMUM TOUCH TARGET (48dp for accessibility) ===
  static const double minTouchTarget = 48;

  // ============================================
  // LIGHT THEME
  // ============================================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: primaryDark,
        error: error,
        surface: white,
        brightness: Brightness.light,
      ),

      // Typography
      textTheme: _buildTextTheme(black, grey600, grey400),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: white,
        foregroundColor: black,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: black,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: grey100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, minTouchTarget),
          side: const BorderSide(color: grey200, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(48, minTouchTarget),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: grey100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 14, color: grey600),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: grey400),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: grey200,
        thickness: 1,
        space: 1,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: grey100,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: black,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    );
  }

  // ============================================
  // DARK THEME
  // ============================================
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primaryLight,
        secondary: primary,
        error: error,
        surface: darkSurface,
        brightness: Brightness.dark,
      ),

      // Typography
      textTheme: _buildTextTheme(darkTextPrimary, darkTextSecondary, darkGrey),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: darkBg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, minTouchTarget),
          side: const BorderSide(color: darkGrey, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(48, minTouchTarget),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 14, color: darkTextSecondary),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: darkGrey),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: darkGrey,
        thickness: 1,
        space: 1,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface2,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: darkTextPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    );
  }

  // === SHARED TEXT THEME ===
  static TextTheme _buildTextTheme(
    Color primary,
    Color secondary,
    Color muted,
  ) {
    return GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
    );
  }

  // === HELPER METHODS ===

  /// Get tolerance color based on value vs target range
  static Color getToleranceColor(double value, double min, double max) {
    if (value < min) return toleranceRed;
    if (value > max) return toleranceGreen;
    return toleranceBlue;
  }

  /// Get tolerance label
  static String getToleranceLabel(double value, double min, double max) {
    if (value < min) return 'Increase';
    if (value > max) return 'Reduce';
    return 'OK';
  }
}
