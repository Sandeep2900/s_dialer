import 'package:flutter/material.dart';

/// One UI Dimension Tokens & Border Radii
class AppDimensions {
  AppDimensions._();

  // Spacing & Padding
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 20.0;
  static const double paddingXL = 24.0;
  static const double paddingXXL = 32.0;

  // Corner Radii (Samsung One UI signature rounded corners)
  static const double radiusS = 8.0;
  static const double radiusM = 14.0;
  static const double radiusL = 20.0; // Standard card
  static const double radiusXL = 26.0; // Dialogs & sheets
  static const double radiusPill = 999.0; // Buttons & search bars

  // Header Heights
  static const double oneUiExpandedHeaderHeight = 160.0;
  static const double oneUiCollapsedHeaderHeight = 56.0;

  // Keypad & Bottom Navigation
  static const double bottomNavHeight = 64.0;
  static const double keypadKeySize = 74.0;
  static const double callButtonSize = 68.0;
  static const double avatarSize = 44.0;
  static const double avatarLargeSize = 88.0;

  // Standard Border Radius Objects
  static final BorderRadius cardBorderRadius = BorderRadius.circular(radiusL);
  static final BorderRadius pillBorderRadius = BorderRadius.circular(radiusPill);
  static final BorderRadius sheetBorderRadius = const BorderRadius.vertical(
    top: Radius.circular(radiusXL),
  );
}
