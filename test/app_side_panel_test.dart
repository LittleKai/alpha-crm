import 'package:alpha_crm/app/theme/app_text_styles.dart';
import 'package:alpha_crm/app/theme/app_theme.dart';
import 'package:alpha_crm/shared/widgets/app_side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    'AppSidePanel supports clamped drag resize (320..600), sticky footer, and Escape close',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      double width = 380.0;
      var closed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Row(
                children: [
                  const Expanded(child: SizedBox()),
                  AppSidePanel(
                    panelKey: const ValueKey('test_side_panel'),
                    width: width,
                    onWidthChanged: (next) => setState(() => width = next),
                    onClose: () => closed = true,
                    header: const Text('Inspector Header'),
                    footer: const Text('Sticky Footer CTA'),
                    child: const Text('Body Content'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inspector Header'), findsOneWidget);
      expect(find.text('Sticky Footer CTA'), findsOneWidget);

      // Drag left edge leftward (negative dx widens right-docked panel past drag slop)
      await tester.drag(
        find.byKey(const ValueKey('app_side_panel_resize_handle')),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();
      expect(width, greaterThan(450.0));
      expect(width, lessThan(AppSidePanel.maxWidth));

      // Drag far left -> clamps to 600.0
      await tester.drag(
        find.byKey(const ValueKey('app_side_panel_resize_handle')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      expect(width, AppSidePanel.maxWidth);

      // Drag far right -> clamps to 320.0
      await tester.drag(
        find.byKey(const ValueKey('app_side_panel_resize_handle')),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();
      expect(width, AppSidePanel.minWidth);

      // Press Escape to close
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    },
  );
}
