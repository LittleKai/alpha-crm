import 'dart:ui';

import 'package:alpha_crm/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Workflow automation route opens from sidebar on desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('Workflow n8n'), findsOneWidget);

    await tester.tap(find.text('Workflow n8n'));
    await tester.pumpAndSettle();

    expect(find.text('Kho workflow mẫu'), findsWidgets);
    expect(find.text('n8n URL ngoài'), findsOneWidget);
  });
}
