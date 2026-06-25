import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Global settings for font customisation
  static double fontSizeMultiplier = 1.0;
  static String fontFamily = 'Be Vietnam Pro';

  static TextStyle _getStyle({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    required Color color,
  }) {
    final double adjustedFontSize = fontSize * fontSizeMultiplier;
    
    switch (fontFamily) {
      case 'Inter':
        return GoogleFonts.inter(
          fontSize: adjustedFontSize,
          fontWeight: fontWeight,
          height: height,
          color: color,
        );
      case 'Roboto':
        return GoogleFonts.roboto(
          fontSize: adjustedFontSize,
          fontWeight: fontWeight,
          height: height,
          color: color,
        );
      case 'Montserrat':
        return GoogleFonts.montserrat(
          fontSize: adjustedFontSize,
          fontWeight: fontWeight,
          height: height,
          color: color,
        );
      case 'Outfit':
        return GoogleFonts.outfit(
          fontSize: adjustedFontSize,
          fontWeight: fontWeight,
          height: height,
          color: color,
        );
      case 'Be Vietnam Pro':
      default:
        return GoogleFonts.beVietnamPro(
          fontSize: adjustedFontSize,
          fontWeight: fontWeight,
          height: height,
          color: color,
        );
    }
  }

  // We use Be Vietnam Pro as it's highly optimized for Vietnamese typography in SaaS UI.
  static TextStyle get pageTitle => _getStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 34 / 28,
    color: AppColors.textPrimary,
  );

  static TextStyle get sectionTitle => _getStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 24 / 18,
    color: AppColors.textPrimary,
  );

  static TextStyle get cardTitle => _getStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 22 / 16,
    color: AppColors.textPrimary,
  );

  static TextStyle get body => _getStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodyMedium => _getStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 22 / 15,
    color: AppColors.textSecondary,
  );

  static TextStyle get label => _getStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );

  static TextStyle get caption => _getStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 18 / 13,
    color: AppColors.textMuted,
  );

  static TextStyle get captionBold => _getStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 18 / 13,
    color: AppColors.textSecondary,
  );
}
