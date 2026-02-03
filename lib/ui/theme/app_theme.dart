import 'package:flutter/material.dart';

class AppTheme {
  // Primary Color
  static const Color primaryColor = Color(0xFF137FEC);

  // Legacy/Specific Colors (Restored for Analytics Chart)
  static const Color primaryBlue = primaryColor;
  static const Color chartLineColor = Color(0xFF00D9FF);
  static const Color chartGridColor = Color(0xFF1A1A2E);
  static const Color chartFillStart = Color(0xFF00D9FF);
  static const Color chartFillEnd = Color(0xFF0066FF);
  static const Color chartBackground = Color(0xFF0F0F1E);

  // Apple Font Families
  static const String fontDisplay = '.SF Pro Display';
  static const String fontText = '.SF Pro Text';

  // Light Theme
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    // SaaS Cool Grey 100
    const Color bgLight = Color(0xFFF3F4F6);
    // Pure White Cards
    const Color surfaceLight = Colors.white;
    // Cool Grey 900 for Text
    const Color textLight = Color(0xFF111827);

    return base.copyWith(
      scaffoldBackgroundColor: bgLight,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        surface: bgLight, // Surface often refers to scaffold bg in M3
        onSurface: textLight,
        background: bgLight,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: fontText,
        bodyColor: textLight,
        displayColor: textLight,
      ).copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(fontFamily: fontDisplay),
        displayMedium: base.textTheme.displayMedium?.copyWith(fontFamily: fontDisplay),
        displaySmall: base.textTheme.displaySmall?.copyWith(fontFamily: fontDisplay),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgLight, // Blend with bg
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textLight),
        titleTextStyle: TextStyle(
          color: textLight,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          fontFamily: fontText,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 10, // Higher elevation value for blur simulation
        shadowColor: const Color(0xFF9CA3AF).withOpacity(0.15), // Soft cool grey shadow
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // More rounded for modern feel
          side: BorderSide.none, // No border, rely on shadow for separation
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 4, // Soft shadow for buttons
          shadowColor: primaryColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
             fontFamily: fontText,
             fontSize: 16,
             fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none, // Clean look
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        floatingLabelStyle: const TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
      ),
      iconTheme: const IconThemeData(color: textLight),
      dividerTheme: DividerThemeData(
        color: const Color(0xFFE5E7EB), // Cool Grey 200
        thickness: 1,
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    // SaaS Cool Grey 900
    const Color bgDark = Color(0xFF111827);
    // Cool Grey 800 for Cards
    const Color surfaceDark = Color(0xFF1F2937);
    // Cool Grey 50 for Text
    const Color textDark = Color(0xFFF9FAFB);

    return base.copyWith(
      scaffoldBackgroundColor: bgDark,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        surface: bgDark,
        onSurface: textDark,
        background: bgDark,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: fontText,
        bodyColor: textDark,
        displayColor: textDark,
      ).copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(fontFamily: fontDisplay),
        displayMedium: base.textTheme.displayMedium?.copyWith(fontFamily: fontDisplay),
        displaySmall: base.textTheme.displaySmall?.copyWith(fontFamily: fontDisplay),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          fontFamily: fontText,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0, // Flat in dark mode usually looks better, or very subtle
        shadowColor: Colors.black.withOpacity(0.4),
        shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(20),
           side: BorderSide(color: const Color(0xFF374151), width: 1), // Cool Grey 700 border
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
             fontFamily: fontText,
             fontSize: 16,
             fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF374151)), // Cool Grey 700
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF374151)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        floatingLabelStyle: const TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
      ),
      iconTheme: const IconThemeData(color: textDark),
      dividerTheme: DividerThemeData(
        color: const Color(0xFF374151), // Cool Grey 700
        thickness: 1,
      ),
    );
  }
}
