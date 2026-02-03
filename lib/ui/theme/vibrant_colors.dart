import 'package:flutter/material.dart';

class VibrantColors {
  // Primary Gradient: Purple to Blue
  static const Color purpleStart = Color(0xFF8B5CF6); // Vibrant Purple
  static const Color purpleEnd = Color(0xFF3B82F6); // Vibrant Blue
  static const Color purpleMid = Color(0xFF6366F1); // Indigo

  // Secondary Gradient: Pink to Orange
  static const Color pinkStart = Color(0xFFEC4899); // Vibrant Pink
  static const Color orangeEnd = Color(0xFFF97316); // Vibrant Orange
  static const Color pinkMid = Color(0xFFF43F5E); // Rose

  // Background: Dark/Deep Blue
  static const Color darkBlue = Color(0xFF0F172A); // Slate 900
  static const Color deepBlue = Color(0xFF1E293B); // Slate 800
  static const Color navyBlue = Color(0xFF1E40AF); // Blue 800

  // Accent Colors
  static const Color cyan = Color(0xFF06B6D4); // Cyan 500
  static const Color emerald = Color(0xFF10B981); // Emerald 500
  static const Color amber = Color(0xFFF59E0B); // Amber 500

  // Gradient Lists
  static List<Color> get primaryGradient => [
        purpleStart,
        purpleMid,
        purpleEnd,
      ];

  static List<Color> get secondaryGradient => [
        pinkStart,
        pinkMid,
        orangeEnd,
      ];

  static List<Color> get backgroundGradient => [
        darkBlue,
        deepBlue,
        navyBlue,
      ];

  // Orb Colors for Background
  static List<Color> get orbColors => [
        purpleStart.withOpacity(0.3),
        pinkStart.withOpacity(0.3),
        cyan.withOpacity(0.3),
        orangeEnd.withOpacity(0.2),
      ];
}



