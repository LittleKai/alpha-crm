import 'package:alpha_crm/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders subscription screen on desktop without layout errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SubscriptionScreen())),
    );
    await tester.pump();

    expect(find.text('Đăng ký & gói AI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders subscription screen on mobile without layout errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SubscriptionScreen())),
    );
    await tester.pump();

    expect(find.text('Đăng ký & gói AI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
