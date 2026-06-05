import 'package:flutter/material.dart';

class AppColors {
  static bool isDarkMode = false;

  // Primary colors
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryHover = Color(0xFF1D4ED8);
  static Color get primarySoft =>
      isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFEAF1FF);
  static Color get primaryBorder =>
      isDarkMode ? const Color(0xFF334155) : const Color(0xFFBFD2FF);
  static const Color zaloBlue = Color(0xFF0068FF);

  // Soft secondary colors
  static Color get purpleSoft =>
      isDarkMode ? const Color(0xFF2E1065) : const Color(0xFFF1E8FF);
  static Color get amberSoft =>
      isDarkMode ? const Color(0xFF451A03) : const Color(0xFFFFF4D6);
  static Color get greenSoft =>
      isDarkMode ? const Color(0xFF064E3B) : const Color(0xFFDFF8EE);
  static Color get cyanSoft =>
      isDarkMode ? const Color(0xFF082F49) : const Color(0xFFE8F7FF);
  static Color get slateSoft =>
      isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

  // Background, surface, border, text
  static Color get appBackground =>
      isDarkMode ? const Color(0xFF0B1120) : const Color(0xFFF6F9FD);
  static Color get surface =>
      isDarkMode ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  static Color get surfaceMuted =>
      isDarkMode ? const Color(0xFF162033) : const Color(0xFFF8FAFC);
  static Color get border =>
      isDarkMode ? const Color(0xFF253247) : const Color(0xFFDBE3EF);
  static Color get borderSoft =>
      isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE7EDF5);

  // All standard texts must be white in dark mode
  static Color get textPrimary =>
      isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  static Color get textSecondary =>
      isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF475569);
  static Color get textMuted =>
      isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF718096);
  static Color get iconMuted =>
      isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static Color get successSoft =>
      isDarkMode ? const Color(0xFF064E3B) : const Color(0xFFDFF8EE);
  static Color get successText =>
      isDarkMode ? const Color(0xFF34D399) : const Color(0xFF047857);

  static const Color warning = Color(0xFFF59E0B);
  static Color get warningSoft =>
      isDarkMode ? const Color(0xFF78350F) : const Color(0xFFFFF4D6);
  static Color get warningText =>
      isDarkMode ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

  static const Color error = Color(0xFFEF4444);
  static Color get errorSoft =>
      isDarkMode ? const Color(0xFF7F1D1D) : const Color(0xFFFDE8E8);
  static Color get errorText =>
      isDarkMode ? const Color(0xFFF87171) : const Color(0xFFDC2626);

  static const Color info = Color(0xFF2563EB);
  static Color get infoSoft =>
      isDarkMode ? const Color(0xFF1E3A8A) : const Color(0xFFEAF6FF);
  static Color get infoText =>
      isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);

  static Color get disabled =>
      isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
  static Color get disabledSoft =>
      isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  static Color get disabledText =>
      isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
}
