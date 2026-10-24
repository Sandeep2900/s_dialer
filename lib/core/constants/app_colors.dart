import 'package:flutter/material.dart';

/// Samsung One UI design system color palette
class AppColors {
  AppColors._();

  // One UI Accent & Brand Colors
  static const Color primaryBlue = Color(0xFF3E91FF); // One UI Blue
  static const Color callGreen = Color(0xFF2DBE60); // Samsung Call Green
  static const Color callGreenPressed = Color(0xFF25A452);
  static const Color endCallRed = Color(0xFFEB5146); // Samsung End Call / Missed Call
  static const Color missedCall = Color(0xFFF05138);

  // Pure Black Dark Theme (One UI AMOLED Black)
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2E);
  static const Color darkCard = Color(0xFF1E1E20);
  static const Color darkDivider = Color(0xFF2A2A2D);
  static const Color darkBorder = Color(0xFF323235);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E93);
  static const Color darkTextTertiary = Color(0xFF636366);
  static const Color darkSearchBackground = Color(0xFF242426);
  static const Color darkKeypadButton = Color(0xFF222225);
  static const Color darkKeypadButtonPressed = Color(0xFF333338);

  // Light Theme (One UI Light)
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0F1F4);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE5E7EB);
  static const Color lightBorder = Color(0xFFE2E4E8);
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightTextTertiary = Color(0xFF9E9E9E);
  static const Color lightSearchBackground = Color(0xFFEDEDF0);
  static const Color lightKeypadButton = Color(0xFFF1F3F6);
  static const Color lightKeypadButtonPressed = Color(0xFFE2E5EB);

  // Swipe Action Colors (Section 5 Spec)
  static const Color swipeCallBackground = Color(0xFF2DBE60); // Green swipe to call
  static const Color swipeMessageBackground = Color(0xFF3E91FF); // Blue swipe to SMS

  // Avatar Palette (Derived from name hash)
  static const List<Color> avatarColors = [
    Color(0xFF3E91FF), // Blue
    Color(0xFF2DBE60), // Green
    Color(0xFFFF9500), // Orange
    Color(0xFFAF52DE), // Purple
    Color(0xFFFF2D55), // Pink
    Color(0xFF5856D6), // Indigo
    Color(0xFF00C7BE), // Teal
    Color(0xFFFF6482), // Coral
    Color(0xFF34C759), // Mint
    Color(0xFFBF5AF2), // Violet
  ];

  /// Get a consistent avatar color for a given contact name
  static Color getAvatarColor(String? name) {
    if (name == null || name.trim().isEmpty) {
      return primaryBlue;
    }
    final int hash = name.trim().codeUnits.fold(0, (prev, code) => prev + code);
    return avatarColors[hash.abs() % avatarColors.length];
  }
}
