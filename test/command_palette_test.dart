import 'package:alpha_crm/app/shell/app_shell.dart';
import 'package:alpha_crm/app/shell/app_shell_providers.dart';
import 'package:alpha_crm/app/shell/app_topbar.dart';
import 'package:alpha_crm/app/shell/command_palette_dialog.dart';
import 'package:alpha_crm/app/theme/app_text_styles.dart';
import 'package:alpha_crm/app/theme/app_theme.dart';
import 'package:alpha_crm/features/security/providers/app_lock_provider.dart';
import 'package:alpha_crm/features/settings/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
    'CommandPaletteDialog supports diacritic-free search, ArrowUp/ArrowDown, and Enter',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => Scaffold(
              appBar: const PreferredSize(
                preferredSize: Size.fromHeight(48),
                child: AppTopbar(currentRoute: '/dashboard'),
              ),
              body: const Text('DASHBOARD'),
            ),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const Scaffold(
              body: Text('CUSTOMERS_TARGET'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('global_search_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('global_search_panel')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('command_palette_input')),
        'khach hang',
      );
      await tester.pumpAndSettle();

      expect(find.text('CRM Khách Hàng'), findsOneWidget);

      // Press Enter to activate top matched entry
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('global_search_panel')), findsNothing);
      expect(find.text('CUSTOMERS_TARGET'), findsOneWidget);
    },
  );

  testWidgets(
    'CommandPaletteDialog ArrowDown selects next action and triggers theme toggle',
    (tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return Builder(
                    builder: (innerContext) => ElevatedButton(
                      onPressed: () => showCommandPaletteDialog(innerContext),
                      child: const Text('OPEN'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('command_palette_input')),
        'giao dien',
      );
      await tester.pumpAndSettle();

      expect(find.text('Chuyển giao diện Sáng / Tối'), findsOneWidget);
      final before = capturedRef.read(settingsProvider).settings.appThemeMode;

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      final after = capturedRef.read(settingsProvider).settings.appThemeMode;
      expect(after, isNot(before));
    },
  );

  testWidgets(
    'CommandPaletteDialog binds Escape & ArrowDown index traversal cleanly',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: CommandPaletteDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default list displays multiple items starting with index 0 highlighted
      expect(
        find.byKey(const ValueKey('command_palette_item_0_selected')),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('command_palette_item_1_selected')),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('command_palette_item_0_selected')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AppShell Ctrl+K shortcut opens CommandPaletteDialog',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(
              state: state,
              child: child,
            ),
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const Text('HOME'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('global_search_panel')), findsOneWidget);

      // Escape closes palette and allows reopening
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('global_search_panel')), findsNothing);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('global_search_panel')), findsOneWidget);
    },
  );

  testWidgets(
    'AppShell toggles sidebar on Ctrl+backslash and ignores global shortcuts when locked',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late WidgetRef capturedRef;
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          ShellRoute(
            builder: (context, state, child) => Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return AppShell(state: state, child: child);
              },
            ),
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const Text('HOME'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedRef.read(sidebarCollapsedProvider), isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.backslash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.backslash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(capturedRef.read(sidebarCollapsedProvider), isTrue);

      // Lock app -> Ctrl+K and Ctrl+\ must be ignored
      capturedRef.read(appLockProvider.notifier).state = const AppLockState(
        hasPassword: true,
        isLocked: true,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('global_search_panel')), findsNothing);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.backslash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.backslash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(capturedRef.read(sidebarCollapsedProvider), isTrue);
    },
  );
}
