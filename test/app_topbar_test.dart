import 'package:alpha_crm/app/shell/app_topbar.dart';
import 'package:alpha_crm/features/dashboard/providers/dashboard_provider.dart';
import 'package:alpha_crm/features/messaging/live_chat/providers/live_chat_provider.dart';
import 'package:alpha_crm/features/tasks/providers/crm_tasks_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppTopbar renders search and notification bell buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(
            (ref) => throw StateError('Topbar must not initialize dashboard'),
          ),
          liveChatProvider.overrideWith(
            (ref) => throw StateError('Topbar must not initialize live chat'),
          ),
          crmTasksProvider.overrideWith(
            (ref) => throw StateError('Topbar must not initialize tasks'),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(64),
              child: AppTopbar(currentRoute: '/dashboard'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('global_search_button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notification_bell_button')),
      findsOneWidget,
    );
  });

  testWidgets('Tapping global search button opens global search panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(64),
              child: AppTopbar(currentRoute: '/dashboard'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap search button
    await tester.tap(find.byKey(const ValueKey('global_search_button')));
    await tester.pumpAndSettle();

    // Search panel should now be open
    expect(find.byKey(const ValueKey('global_search_panel')), findsOneWidget);
  });

  testWidgets('Tapping notification bell button opens notification menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(64),
              child: AppTopbar(currentRoute: '/dashboard'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap notification bell button
    await tester.tap(find.byKey(const ValueKey('notification_bell_button')));
    await tester.pumpAndSettle();

    // Notification menu should now be open
    expect(find.byKey(const ValueKey('notification_menu')), findsOneWidget);
  });
}
