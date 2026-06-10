import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alpha_crm/main.dart';

void main() {
  testWidgets('App shell and routing smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Let GoRouter resolve initial route and pump
    await tester.pumpAndSettle();

    // Verify that the branding 'ALPHA CRM' exists
    expect(find.text('ALPHA CRM'), findsOneWidget);

    // Verify that we are on the dashboard (it appears twice: in Sidebar and in Header)
    expect(find.text('Tổng quan chiến dịch'), findsNWidgets(2));
  });
}
