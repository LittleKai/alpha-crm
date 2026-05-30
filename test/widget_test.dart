import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alpha_crm/main.dart';

void main() {
  testWidgets('App shell and routing smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Let GoRouter resolve initial route and pump
    await tester.pumpAndSettle();

    // Verify that the branding 'CRM ZALO' exists
    expect(find.text('CRM ZALO'), findsOneWidget);

    // Verify that we are on the dashboard (it appears twice: in Sidebar and in Header)
    expect(find.text('Tổng quan chiến dịch'), findsNWidgets(2));
  });
}
