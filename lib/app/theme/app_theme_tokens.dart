import 'package:flutter/material.dart';

/// Semantic Light/Dark design tokens modeled after Twenty UI (MIT) Preset A:
/// Calm neutral frame (`#F1F1F1` / `#1D1D1D`) cradling an elevated primary
/// workspace pane (`#FFFFFF` / `#171717`) with hairline `1px` borders and a
/// disciplined 4-step typography scale.
@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  final Color canvasBackground;
  final Color surfacePrimary;
  final Color surfaceSecondary;
  final Color surfaceQuaternary;
  final Color transparentLighter;
  final Color transparentLight;
  final Color transparentMedium;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textLight;
  final Color borderLight;
  final Color borderMedium;
  final Color borderStrong;
  final Color accentBlue;
  final Color infoBg;
  final Color infoText;
  final Color successBg;
  final Color successText;
  final Color warningBg;
  final Color warningText;
  final Color dangerBg;
  final Color dangerText;

  const AppThemeTokens({
    required this.canvasBackground,
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.surfaceQuaternary,
    required this.transparentLighter,
    required this.transparentLight,
    required this.transparentMedium,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textLight,
    required this.borderLight,
    required this.borderMedium,
    required this.borderStrong,
    required this.accentBlue,
    required this.infoBg,
    required this.infoText,
    required this.successBg,
    required this.successText,
    required this.warningBg,
    required this.warningText,
    required this.dangerBg,
    required this.dangerText,
  });

  static const AppThemeTokens light = AppThemeTokens(
    canvasBackground: Color(0xFFF1F1F1),
    surfacePrimary: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFFAFAFA),
    surfaceQuaternary: Color(0xFFEBEBEB),
    transparentLighter: Color(0x05000000),
    transparentLight: Color(0x0A000000),
    transparentMedium: Color(0x14000000),
    textPrimary: Color(0xFF333333),
    textSecondary: Color(0xFF666666),
    textTertiary: Color(0xFF999999),
    textLight: Color(0xFFB3B3B3),
    borderLight: Color(0xFFF1F1F1),
    borderMedium: Color(0xFFEBEBEB),
    borderStrong: Color(0xFFD6D6D6),
    accentBlue: Color(0xFF2563EB),
    infoBg: Color(0xFFE8F0FF),
    infoText: Color(0xFF1D4ED8),
    successBg: Color(0xFFE6F6EC),
    successText: Color(0xFF15803D),
    warningBg: Color(0xFFFFF4DB),
    warningText: Color(0xFFB45309),
    dangerBg: Color(0xFFFEECEE),
    dangerText: Color(0xFFDC2626),
  );

  static const AppThemeTokens dark = AppThemeTokens(
    canvasBackground: Color(0xFF1D1D1D),
    surfacePrimary: Color(0xFF171717),
    surfaceSecondary: Color(0xFF1B1B1B),
    surfaceQuaternary: Color(0xFF222222),
    transparentLighter: Color(0x0DFFFFFF),
    transparentLight: Color(0x0FFFFFFF),
    transparentMedium: Color(0x1AFFFFFF),
    textPrimary: Color(0xFFEBEBEB),
    textSecondary: Color(0xFFB3B3B3),
    textTertiary: Color(0xFF818181),
    textLight: Color(0xFF666666),
    borderLight: Color(0xFF1D1D1D),
    borderMedium: Color(0xFF282828),
    borderStrong: Color(0xFF484848),
    accentBlue: Color(0xFF60A5FA),
    infoBg: Color(0xFF1A2446),
    infoText: Color(0xFF93B4FF),
    successBg: Color(0xFF192C22),
    successText: Color(0xFF6EE7B7),
    warningBg: Color(0xFF2D200C),
    warningText: Color(0xFFFCD34D),
    dangerBg: Color(0xFF361519),
    dangerText: Color(0xFFFCA5A5),
  );

  /// Safe accessor falling back to Light/Dark defaults when a widget tree uses
  /// a bare [MaterialApp] (e.g. isolated widget tests) without [AppTheme].
  static AppThemeTokens of(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeTokens>();
    if (ext != null) return ext;
    return theme.brightness == Brightness.dark ? dark : light;
  }

  @override
  AppThemeTokens copyWith({
    Color? canvasBackground,
    Color? surfacePrimary,
    Color? surfaceSecondary,
    Color? surfaceQuaternary,
    Color? transparentLighter,
    Color? transparentLight,
    Color? transparentMedium,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textLight,
    Color? borderLight,
    Color? borderMedium,
    Color? borderStrong,
    Color? accentBlue,
    Color? infoBg,
    Color? infoText,
    Color? successBg,
    Color? successText,
    Color? warningBg,
    Color? warningText,
    Color? dangerBg,
    Color? dangerText,
  }) {
    return AppThemeTokens(
      canvasBackground: canvasBackground ?? this.canvasBackground,
      surfacePrimary: surfacePrimary ?? this.surfacePrimary,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      surfaceQuaternary: surfaceQuaternary ?? this.surfaceQuaternary,
      transparentLighter: transparentLighter ?? this.transparentLighter,
      transparentLight: transparentLight ?? this.transparentLight,
      transparentMedium: transparentMedium ?? this.transparentMedium,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textLight: textLight ?? this.textLight,
      borderLight: borderLight ?? this.borderLight,
      borderMedium: borderMedium ?? this.borderMedium,
      borderStrong: borderStrong ?? this.borderStrong,
      accentBlue: accentBlue ?? this.accentBlue,
      infoBg: infoBg ?? this.infoBg,
      infoText: infoText ?? this.infoText,
      successBg: successBg ?? this.successBg,
      successText: successText ?? this.successText,
      warningBg: warningBg ?? this.warningBg,
      warningText: warningText ?? this.warningText,
      dangerBg: dangerBg ?? this.dangerBg,
      dangerText: dangerText ?? this.dangerText,
    );
  }

  @override
  AppThemeTokens lerp(covariant ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      canvasBackground: Color.lerp(canvasBackground, other.canvasBackground, t)!,
      surfacePrimary: Color.lerp(surfacePrimary, other.surfacePrimary, t)!,
      surfaceSecondary: Color.lerp(surfaceSecondary, other.surfaceSecondary, t)!,
      surfaceQuaternary: Color.lerp(surfaceQuaternary, other.surfaceQuaternary, t)!,
      transparentLighter: Color.lerp(transparentLighter, other.transparentLighter, t)!,
      transparentLight: Color.lerp(transparentLight, other.transparentLight, t)!,
      transparentMedium: Color.lerp(transparentMedium, other.transparentMedium, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textLight: Color.lerp(textLight, other.textLight, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      borderMedium: Color.lerp(borderMedium, other.borderMedium, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      infoText: Color.lerp(infoText, other.infoText, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
    );
  }
}
