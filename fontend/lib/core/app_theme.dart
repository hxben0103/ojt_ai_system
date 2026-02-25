import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized app theme for consistent styling across all dashboards
class AppTheme {
  // Deeper primary colors for a more premium look
  static const Color studentPrimary = Color(0xFF1565C0); // Deep Blue
  static const Color coordinatorPrimary = Color(0xFF6A1B9A); // Deep Purple
  static const Color supervisorPrimary = Color(0xFF00695C); // Deep Teal
  static const Color adminPrimary = Color(0xFFB71C1C); // Deep Red

  // Common colors
  static const Color successColor = Color(0xFF2E7D32); // Deeper Green
  static const Color warningColor = Color(0xFFEF6C00); // Deeper Orange
  static const Color errorColor = Color(0xFFC62828);
  static const Color infoColor = Color(0xFF0277BD);
  static const Color surfaceColor = Color(0xFFF0F2F5); // Slightly blueish-grey background

  // Spacing scale (8pt foundation)
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  // Border radius
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXL = 24.0;

  // Card shadow decoration
  static const BoxShadow cardShadow = BoxShadow(
    color: Colors.black12,
    blurRadius: 10,
    offset: Offset(0, 4),
  );

  // Text styles using Google Fonts Inter
  static TextStyle get heading1 => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      );

  static TextStyle get heading2 => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      );

  static TextStyle get heading3 => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        color: Colors.black87,
        letterSpacing: 0.15,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        color: Colors.black87,
        letterSpacing: 0.25,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        color: Colors.black54,
        letterSpacing: 0.4,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        color: Colors.black38,
        letterSpacing: 0.4,
      );

  /// Material 3 light theme used by the app.
  static ThemeData get lightTheme {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        primary: studentPrimary,
        secondary: coordinatorPrimary,
      ),
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(),
    );

    return base.copyWith(
      scaffoldBackgroundColor: surfaceColor,
      textTheme: base.textTheme.copyWith(
        displayLarge: heading1,
        displayMedium: heading2,
        titleLarge: heading3,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelSmall: caption,
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 0, // We use BoxShadow for controlled look
        margin: const EdgeInsets.symmetric(
          horizontal: spacing16,
          vertical: spacing8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 4,
        centerTitle: false,
        backgroundColor: studentPrimary,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMedium),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMedium),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
        ),
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
      ),
    );
  }

  // Get role-specific primary color
  static Color getRoleColor(String role) {
    final roleLower = role.toLowerCase();
    if (roleLower.contains('student')) return studentPrimary;
    if (roleLower.contains('coordinator')) return coordinatorPrimary;
    if (roleLower.contains('supervisor')) return supervisorPrimary;
    if (roleLower.contains('admin')) return adminPrimary;
    return studentPrimary;
  }

  // Create primary button style
  static ButtonStyle primaryButtonStyle(Color primaryColor) {
    return ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
      ),
      elevation: 4,
      shadowColor: primaryColor.withOpacity(0.4),
    );
  }

  // Create secondary button style
  static ButtonStyle secondaryButtonStyle(Color primaryColor) {
    return OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      side: BorderSide(color: primaryColor, width: 2),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
      ),
    );
  }
}

