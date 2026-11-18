import 'package:alpha_crm/app/theme/app_text_styles.dart';
import 'package:alpha_crm/app/theme/app_theme.dart';
import 'package:alpha_crm/features/customers/presentation/widgets/customer_import_wizard.dart';
import 'package:alpha_crm/features/customers/utils/customer_file_parser.dart';
import 'package:alpha_crm/mock/mock_contacts.dart';
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

  test('detectHeaderRowIndex and suggestImportMappings handle shifted header rows', () {
    final rows = [
      ['DANH SÁCH KHÁCH HÀNG THÁNG 11'],
      ['Họ và tên', 'SĐT', 'Nhóm', 'Ghi chú'],
      ['Nguyễn An', '0901234567', 'VIP', 'Quan tâm'],
    ];

    final headerIdx = detectHeaderRowIndex(rows);
    expect(headerIdx, 1);

    final mappings = suggestImportMappings(rows, headerRowIndex: headerIdx);
    expect(mappings[0].targetField, ImportTargetField.name);
    expect(mappings[0].sampleValue, 'Nguyễn An');
    expect(mappings[1].targetField, ImportTargetField.phone);
    expect(mappings[2].targetField, ImportTargetField.group);
    expect(mappings[3].targetField, ImportTargetField.custom);
    expect(mappings[3].customKey, 'ghi_chu');
  });

  testWidgets(
    'CustomerImportWizardDialog supports header shift, conflict-free remap, and error filtering',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final rawRows = [
        ['BẢNG DỮ LIỆU XUẤT'],
        ['Tên khách', 'Điện thoại', 'Nhóm'],
        ['Trần Minh', '0987654321', 'VIP'],
        ['Khách Lỗi', '123', 'Đối tác'],
      ];

      List<Contact>? importedResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  importedResult = await showCustomerImportWizardDialog(
                    context,
                    fileName: 'clients.xlsx',
                    rawRows: rawRows,
                    customAttributes: const [],
                  );
                },
                child: const Text('OPEN_WIZARD'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN_WIZARD'));
      await tester.pumpAndSettle();

      // Header was auto-detected at row index 1 -> opens on Step 1 Select Header
      expect(
        find.byKey(const ValueKey('customer_import_wizard_dialog')),
        findsOneWidget,
      );
      await tester.tap(find.text('Tiếp tục ghép cột'));
      await tester.pumpAndSettle();

      // Now on Step 2 Match Columns
      expect(
        find.byKey(const ValueKey('import_col_dropdown_0')),
        findsOneWidget,
      );

      await tester.tap(find.text('Kiểm tra dữ liệu'));
      await tester.pumpAndSettle();

      // Now on Step 3 Validate: 1 valid + 1 error ('123' < 8 digits)
      expect(find.text('Hợp lệ: 1'), findsOneWidget);
      expect(find.text('Có lỗi: 1'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('import_wizard_only_errors_switch')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Khách Lỗi'), findsOneWidget);
      expect(find.text('Trần Minh'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('import_wizard_only_errors_switch')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nhập 1 khách hàng'));
      await tester.pumpAndSettle();

      expect(importedResult, isNotNull);
      expect(importedResult, hasLength(1));
      expect(importedResult!.single.name, 'Trần Minh');
      expect(importedResult!.single.phone, '0987654321');
    },
  );

  testWidgets(
    'CustomerImportWizardDialog validates multi-thousand row batch off UI isolate',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final rawRows = <List<String>>[
        ['Họ và tên', 'Số điện thoại'],
        for (var i = 0; i < 2500; i++)
          ['Khách $i', '09${(10000000 + i).toString()}'],
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CustomerImportWizardDialog(
              fileName: 'batch.csv',
              rawRows: rawRows,
              customAttributes: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kiểm tra dữ liệu'));
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
        if (find.text('Hợp lệ: 2500').evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();

      expect(find.text('Hợp lệ: 2500'), findsOneWidget);
      expect(find.text('Có lỗi: 0'), findsOneWidget);
      expect(find.text('Nhập 2500 khách hàng'), findsOneWidget);
    },
  );
}
