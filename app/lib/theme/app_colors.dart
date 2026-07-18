import 'package:flutter/material.dart';

/// Centralized palette matching the dark "tactical command"
/// look from the approved mockups. Touch this file, not raw
/// hex codes scattered across widgets.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0A0D12);
  static const Color surface = Color(0xFF12161F);
  static const Color surfaceElevated = Color(0xFF161B26);
  static const Color border = Color(0xFF222936);

  static const Color textPrimary = Color(0xFFE7ECF2);
  static const Color textSecondary = Color(0xFF8A94A6);
  static const Color textMuted = Color(0xFF565F70);

  static const Color accentCyan = Color(0xFF4FD1E8);
  static const Color accentMagenta = Color(0xFFE8447A);
  static const Color accentGreen = Color(0xFF3DDC97);
  static const Color accentAmber = Color(0xFFE8A33D);

  static const Color statusCompleted = accentGreen;
  static const Color statusAnalyzing = accentCyan;
  static const Color statusAlert = accentMagenta;
}