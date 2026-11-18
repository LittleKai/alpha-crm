import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';
import 'app_theme_tokens.dart';

class AppTheme {
  static ThemeData get lightTheme {
    const tokens = AppThemeTokens.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        primary: const Color(0xFF2563EB),
        secondary: const Color(0xFF0068FF),
        surface: tokens.surfacePrimary,
        error: const Color(0xFFEF4444),
      ),
      scaffoldBackgroundColor: tokens.canvasBackground,
      extensions: const <ThemeExtension<dynamic>>[tokens],
      cardTheme: CardThemeData(
        color: tokens.surfacePrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusM,
          side: BorderSide(color: tokens.borderMedium, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: tokens.borderMedium,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.sm, // Standardized padding
        ),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusS,
          borderSide: BorderSide(color: AppColors.borderSoft, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusS,
          borderSide: BorderSide(color: AppColors.borderSoft, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusS,
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusS,
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        hintStyle: AppTextStyles.body.copyWith(color: const Color(0xFF718096)),
        labelStyle: AppTextStyles.label,
        errorStyle: AppTextStyles.caption.copyWith(color: const Color(0xFFDC2626)),
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.pageTitle,
        titleLarge: AppTextStyles.sectionTitle,
        titleMedium: AppTextStyles.cardTitle,
        bodyLarge: AppTextStyles.bodyMedium,
        bodyMedium: AppTextStyles.body,
        labelLarge: AppTextStyles.label,
        bodySmall: AppTextStyles.caption,
      ),
    );
  }

  static ThemeData get darkTheme {
    const tokens = AppThemeTokens.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: tokens.accentBlue,
      brightness: Brightness.dark,
      primary: tokens.accentBlue,
      secondary: const Color(0xFF38BDF8),
      surface: tokens.surfacePrimary,
      error: const Color(0xFFF87171),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.canvasBackground,
      extensions: const <ThemeExtension<dynamic>>[tokens],
      cardTheme: CardThemeData(
        color: tokens.surfacePrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusM,
          side: BorderSide(color: tokens.borderMedium, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: tokens.borderMedium,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusS,
          borderSide: BorderSide(color: tokens.borderMedium, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusS,
          borderSide: BorderSide(color: tokens.borderMedium, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusS,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.pageTitle,
        titleLarge: AppTextStyles.sectionTitle,
        titleMedium: AppTextStyles.cardTitle,
        bodyLarge: AppTextStyles.bodyMedium,
        bodyMedium: AppTextStyles.body,
        labelLarge: AppTextStyles.label,
        bodySmall: AppTextStyles.caption,
      ),
    );
  }
}
