import 'package:alpha_crm/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'DashboardScreen renders all Phase 2 operational/analytics sections',
    (tester) async {
      // Set desktop width
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: DashboardScreen())),
        ),
      );

      // Wait for build
      await tester.pumpAndSettle();

      // Check that existing elements (like header) are found
      expect(find.text('Tổng quan chiến dịch'), findsOneWidget);

      // Expect Phase 2 sections to be found (these will fail initially)
      expect(
        find.byKey(const ValueKey('dashboard_pipeline_section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard_source_section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard_campaign_status_section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard_zalo_onboarding_banner')),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    },
  );
}
