import 'package:alpha_crm/app/shell/app_shell_providers.dart';
import 'package:alpha_crm/app/shell/app_sidebar.dart';
import 'package:alpha_crm/app/shell/nav_item_models.dart';
import 'package:alpha_crm/app/theme/app_text_styles.dart';
import 'package:alpha_crm/app/theme/app_theme.dart';
import 'package:alpha_crm/app/theme/app_theme_tokens.dart';
import 'package:alpha_crm/features/settings/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  testWidgets(
    'AppSidebar adapts to Light/Dark Preset A surfaces and uses monochrome icons',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Verify all nav items stripped rainbow overrides
      for (final group in navigationGroups) {
        for (final item in group.items) {
          expect(item.color, isNull, reason: '${item.routePath} must be monochrome');
        }
      }

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Row(
                children: [
                  AppSidebar(currentRoute: '/customers'),
                  Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final surfaceBox = tester.widget<Container>(
        find.byKey(const ValueKey('app_sidebar_surface')),
      );
      final decoration = surfaceBox.decoration as BoxDecoration;
      expect(decoration.color, AppThemeTokens.light.canvasBackground);
      expect(
        find.byKey(const ValueKey('sidebar_collapse_button')),
        findsOneWidget,
      );

      // Verify TikTok icon is not invisible black (#010101)
      final tiktokIcon = tester.widget<Icon>(
        find.byIcon(Icons.music_note_outlined),
      );
      expect(tiktokIcon.color, AppThemeTokens.light.textSecondary);

      // Dark mode adaptation
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            key: const ValueKey('dark_sidebar'),
            themeMode: ThemeMode.dark,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const Scaffold(
              body: Row(
                children: [
                  AppSidebar(currentRoute: '/customers'),
                  Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkSurface = tester.widget<Container>(
        find.byKey(const ValueKey('app_sidebar_surface')),
      );
      final darkDecoration = darkSurface.decoration as BoxDecoration;
      expect(darkDecoration.color, AppThemeTokens.dark.canvasBackground);
      final activeCustomerIcon = tester.widget<Icon>(
        find.byIcon(Icons.people_outline),
      );
      expect(activeCustomerIcon.color, AppThemeTokens.dark.textPrimary);
    },
  );

  testWidgets(
    'AppSidebar collapse button & drag handle persist collapsed state and clamped width',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return const Row(
                    children: [
                      AppSidebar(currentRoute: '/dashboard'),
                      Expanded(child: SizedBox()),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedRef.read(sidebarWidthProvider), kSidebarDefaultWidth);
      expect(capturedRef.read(sidebarCollapsedProvider), isFalse);

      // Drag resize handle wider
      await tester.drag(
        find.byKey(const ValueKey('sidebar_resize_handle')),
        const Offset(60, 0),
      );
      await tester.pumpAndSettle();
      expect(capturedRef.read(sidebarWidthProvider), 280.0);
      expect(
        capturedRef.read(settingsProvider).settings.sidebarWidth,
        280.0,
      );

      // Drag way beyond max -> clamps to 350.0
      await tester.drag(
        find.byKey(const ValueKey('sidebar_resize_handle')),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();
      expect(capturedRef.read(sidebarWidthProvider), kSidebarMaxWidth);

      // Click inline collapse button -> collapses & updates settingsProvider
      await tester.tap(find.byKey(const ValueKey('sidebar_collapse_button')));
      await tester.pumpAndSettle();
      expect(capturedRef.read(sidebarCollapsedProvider), isTrue);
      expect(
        capturedRef.read(settingsProvider).settings.sidebarCollapsed,
        isTrue,
      );
    },
  );
}
