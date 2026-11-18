import 'package:alpha_crm/app/theme/app_colors.dart';
import 'package:alpha_crm/app/theme/app_text_styles.dart';
import 'package:alpha_crm/app/theme/app_theme.dart';
import 'package:alpha_crm/app/theme/app_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String prevFont;

  setUpAll(() {
    prevFont = AppTextStyles.fontFamily;
    AppTextStyles.fontFamily = 'System';
  });

  tearDownAll(() {
    AppTextStyles.fontFamily = prevFont;
  });

  test('AppThemeTokens exposes distinct Preset A Light & Dark tokens', () {
    final light = AppTheme.lightTheme.extension<AppThemeTokens>();
    final dark = AppTheme.darkTheme.extension<AppThemeTokens>();

    expect(light, isNotNull);
    expect(dark, isNotNull);

    // Twenty Calm Neutral Preset A surfaces
    expect(light!.canvasBackground, const Color(0xFFF1F1F1));
    expect(light.surfacePrimary, const Color(0xFFFFFFFF));
    expect(dark!.canvasBackground, const Color(0xFF1D1D1D));
    expect(dark.surfacePrimary, const Color(0xFF171717));

    // Typography hierarchy must be distinct in both modes
    expect(light.textPrimary, isNot(light.textSecondary));
    expect(light.textSecondary, isNot(light.textTertiary));
    expect(dark.textPrimary, isNot(dark.textSecondary));
    expect(dark.textSecondary, isNot(dark.textTertiary));
    expect(dark.textTertiary, isNot(dark.textLight));

    // ThemeExtension lerp transitions smoothly
    final mid = light.lerp(dark, 0.5);
    expect(mid.canvasBackground, isNot(light.canvasBackground));
    expect(mid.canvasBackground, isNot(dark.canvasBackground));
  });

  test('AppColors Dark mode maintains legible contrast and hierarchy', () {
    final previous = AppColors.isDarkMode;
    addTearDown(() => AppColors.isDarkMode = previous);

    AppColors.isDarkMode = true;
    expect(AppColors.surface.toARGB32(), 0xFF111827);
    expect(AppColors.textPrimary, isNot(AppColors.textSecondary));
    expect(AppColors.textSecondary, isNot(AppColors.textMuted));
    expect(AppColors.primary, isNot(const Color(0xFFFFFFFF)));
  });

  testWidgets('AppThemeTokens.of gracefully falls back on bare MaterialApp', (
    tester,
  ) async {
    late AppThemeTokens resolvedLight;
    late AppThemeTokens resolvedDark;

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('light'),
        theme: ThemeData.light(),
        home: Builder(
          builder: (context) {
            resolvedLight = AppThemeTokens.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolvedLight.canvasBackground, AppThemeTokens.light.canvasBackground);

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('dark'),
        themeMode: ThemeMode.dark,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: Builder(
          builder: (context) {
            resolvedDark = AppThemeTokens.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolvedDark.canvasBackground, AppThemeTokens.dark.canvasBackground);
  });
}
