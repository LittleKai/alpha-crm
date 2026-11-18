import 'package:alpha_crm/app/theme/app_text_styles.dart';
import 'package:alpha_crm/app/theme/app_theme.dart';
import 'package:alpha_crm/shared/widgets/view_chip_bar.dart';
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

  testWidgets('ViewChipBar renders removable filter chips and Reset action', (
    tester,
  ) async {
    var groupRemoved = false;
    var resetCalled = false;
    var saveCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ViewChipBar(
            chips: [
              ViewFilterChipItem(
                id: 'group',
                label: 'Nhóm',
                value: 'Khách hàng VIP',
                icon: Icons.group_outlined,
                onRemove: () => groupRemoved = true,
              ),
              ViewFilterChipItem(
                id: 'status',
                label: 'Trạng thái',
                value: 'Thành công',
                icon: Icons.verified_outlined,
                onRemove: () {},
              ),
            ],
            onReset: () => resetCalled = true,
            onSaveSegment: () => saveCalled = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nhóm: '), findsOneWidget);
    expect(find.text('Khách hàng VIP'), findsOneWidget);
    expect(find.text('Trạng thái: '), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('view_chip_remove_group')));
    await tester.pumpAndSettle();
    expect(groupRemoved, isTrue);

    await tester.tap(find.byKey(const ValueKey('view_chip_reset_button')));
    await tester.pumpAndSettle();
    expect(resetCalled, isTrue);

    await tester.tap(find.byKey(const ValueKey('view_chip_save_segment')));
    await tester.pumpAndSettle();
    expect(saveCalled, isTrue);
  });

  testWidgets('ViewChipBar collapses to zero height when empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: ViewChipBar(chips: []),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('view_chip_bar')), findsNothing);
  });
}
