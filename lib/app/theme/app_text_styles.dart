import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // We use Be Vietnam Pro as it's highly optimized for Vietnamese typography in SaaS UI.
  static TextStyle get pageTitle => GoogleFonts.beVietnamPro(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 34 / 28,
    color: AppColors.textPrimary,
  );

  static TextStyle get sectionTitle => GoogleFonts.beVietnamPro(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 24 / 18,
    color: AppColors.textPrimary,
  );

  static TextStyle get cardTitle => GoogleFonts.beVietnamPro(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 22 / 16,
    color: AppColors.textPrimary,
  );

  static TextStyle get body => GoogleFonts.beVietnamPro(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodyMedium => GoogleFonts.beVietnamPro(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 22 / 15,
    color: AppColors.textSecondary,
  );

  static TextStyle get label => GoogleFonts.beVietnamPro(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );

  static TextStyle get caption => GoogleFonts.beVietnamPro(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 18 / 13,
    color: AppColors.textMuted,
  );

  static TextStyle get captionBold => GoogleFonts.beVietnamPro(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 18 / 13,
    color: AppColors.textSecondary,
  );
}
