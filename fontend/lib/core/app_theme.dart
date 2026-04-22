import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized app theme for consistent styling across all dashboards
class AppTheme {
  // Deeper primary colors for a more premium look
  // Deeper primary colors for a more professional, trustworthy look
  static const Color studentPrimary = Color(0xFF0F172A); // Navy Slate
  static const Color coordinatorPrimary = Color(0xFF312E81); // Indigo
  static const Color supervisorPrimary = Color(0xFF064E3B); // Deep Emerald
  static const Color adminPrimary = Color(0xFF7F1D1D); // Crimson

  // Common colors for a cleaner palette
  static const Color successColor = Color(0xFF10B981); // Emerald
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color errorColor = Color(0xFFEF4444); // Rose
  static const Color infoColor = Color(0xFF3B82F6); // Blue
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

  // Pro-level Soft Shadows
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 1,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 15,
      offset: Offset(0, 10),
    ),
  ];

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  // Text styles using Outfit (Headings) and Plus Jakarta Sans (Body)
  static TextStyle get heading1 => GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0F172A),
        letterSpacing: -0.5,
      );

  static TextStyle get heading2 => GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1E293B),
        letterSpacing: -0.3,
      );

  static TextStyle get heading3 => GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF334155),
      );

  static TextStyle get bodyLarge => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        color: const Color(0xFF334155),
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: const Color(0xFF475569),
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        color: const Color(0xFF64748B),
      );

  static TextStyle get caption => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        color: const Color(0xFF94A3B8),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
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
      textTheme: GoogleFonts.interTextTheme().apply(
        fontFamilyFallback: ['NotoColorEmoji', 'NotoSans'],
      ),
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


