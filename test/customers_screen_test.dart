import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:alpha_crm/features/customers/data/customers_repository.dart';
import 'package:alpha_crm/features/customers/data/segments_repository.dart';
import 'package:alpha_crm/features/customers/presentation/screens/customers_screen.dart';
import 'package:alpha_crm/features/customers/providers/customers_provider.dart';
import 'package:alpha_crm/features/customers/utils/customer_file_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCustomersRepository extends CustomersRepository {
  @override
  Future<Map<String, dynamic>> getCustomers({
    String? search,
    String? status,
    String? tag,
    String? lifecycleStage,
    String? segmentId,
    int? page,
    int? limit,
  }) async {
    return {
      'success': true,
      'data': [
        {
          '_id': 'c1',
          'name': 'Nguyen Van A',
          'phone': '0987654321',
          'company': 'Khach hang VIP',
          'notes': 'Bat dong san',
          'status': 'lead',
          'createdAt': '2026-06-01T00:00:00.000Z',
        },
        {
          '_id': 'c2',
          'name': 'Tran Thi B',
          'phone': '0912345678',
          'company': 'Doi tac',
          'notes': 'Tai chinh',
          'status': 'customer',
          'createdAt': '2026-06-02T00:00:00.000Z',
        },
      ],
    };
  }
}

class _FakeSegmentsRepository extends SegmentsRepository {
  @override
  Future<Map<String, dynamic>> getSegments() async {
    return {'success': true, 'data': []};
  }
}

Uint8List _buildMinimalXlsx(Map<String, String> textEntries) {
  final rawZlib = ZLibCodec(raw: true);
  final localParts = BytesBuilder();
  final centralParts = BytesBuilder();
  var offset = 0;

  void writeUint16(BytesBuilder b, int v) {
    final bd = ByteData(2)..setUint16(0, v, Endian.little);
    b.add(bd.buffer.asUint8List());
  }

  void writeUint32(BytesBuilder b, int v) {
    final bd = ByteData(4)..setUint32(0, v, Endian.little);
    b.add(bd.buffer.asUint8List());
  }

  var count = 0;
  for (final entry in textEntries.entries) {
    count++;
    final nameBytes = utf8.encode(entry.key);
    final rawBytes = utf8.encode(entry.value);
    final compBytes = rawZlib.encode(rawBytes);
    final localOffset = offset;

    writeUint32(localParts, 0x04034b50);
    writeUint16(localParts, 20);
    writeUint16(localParts, 0);
    writeUint16(localParts, 8);
    writeUint16(localParts, 0);
    writeUint16(localParts, 0);
    writeUint32(localParts, 0);
    writeUint32(localParts, compBytes.length);
    writeUint32(localParts, rawBytes.length);
    writeUint16(localParts, nameBytes.length);
    writeUint16(localParts, 0);
    localParts.add(nameBytes);
    localParts.add(compBytes);
    offset = localParts.length;

    writeUint32(centralParts, 0x02014b50);
    writeUint16(centralParts, 20);
    writeUint16(centralParts, 20);
    writeUint16(centralParts, 0);
    writeUint16(centralParts, 8);
    writeUint16(centralParts, 0);
    writeUint16(centralParts, 0);
    writeUint32(centralParts, 0);
    writeUint32(centralParts, compBytes.length);
    writeUint32(centralParts, rawBytes.length);
    writeUint16(centralParts, nameBytes.length);
    writeUint16(centralParts, 0);
    writeUint16(centralParts, 0);
    writeUint16(centralParts, 0);
    writeUint16(centralParts, 0);
    writeUint32(centralParts, 0);
    writeUint32(centralParts, localOffset);
    centralParts.add(nameBytes);
  }

  final cdOffset = localParts.length;
  final cdBytes = centralParts.toBytes();
  localParts.add(cdBytes);

  writeUint32(localParts, 0x06054b50);
  writeUint16(localParts, 0);
  writeUint16(localParts, 0);
  writeUint16(localParts, count);
  writeUint16(localParts, count);
  writeUint32(localParts, cdBytes.length);
  writeUint32(localParts, cdOffset);
  writeUint16(localParts, 0);

  return localParts.toBytes();
}

void main() {
  testWidgets(
    'customers screen shows pipeline summary and desktop detail panel',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customersRepositoryProvider.overrideWithValue(
              _FakeCustomersRepository(),
            ),
            segmentsRepositoryProvider.overrideWithValue(
              _FakeSegmentsRepository(),
            ),
          ],
          child: const MaterialApp(home: CustomersScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('customers_pipeline_summary')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('customer_detail_panel')), findsNothing);

      await tester.tap(find.text('Nguyen Van A').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('customer_detail_panel')),
        findsOneWidget,
      );
      expect(find.text('0987654321'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  test('parseCustomerImportBytes parses Vietnamese CSV with custom columns', () {
    const csv =
        'Họ và tên,Số điện thoại,Nhóm khách hàng,Lĩnh vực,Ngân sách\r\n'
        '"Nguyễn Văn An",0901234567,"Khách hàng VIP","Bất động sản","5 tỷ"\r\n'
        'Trần Thị Bình,0912345678,Đối tác,Tài chính,2 tỷ\r\n';
    final contacts = parseCustomerImportBytes(
      Uint8List.fromList(utf8.encode(csv)),
      'khach_hang.csv',
    );

    expect(contacts, hasLength(2));
    expect(contacts[0].name, 'Nguyễn Văn An');
    expect(contacts[0].phone, '0901234567');
    expect(contacts[0].group, 'Khách hàng VIP');
    expect(contacts[0].tag, 'Bất động sản');
    expect(contacts[0].customAttributes['ngan_sach'], '5 tỷ');
    expect(contacts[1].name, 'Trần Thị Bình');
    expect(contacts[1].phone, '0912345678');
  });

  test('parseCustomerImportBytes parses real XLSX worksheet and sharedStrings', () {
    final xlsxBytes = _buildMinimalXlsx({
      'xl/sharedStrings.xml':
          '<sst><si><t>Họ tên</t></si><si><t>SĐT</t></si>'
          '<si><t>Lê Hoàng</t></si><si><t>0988776655</t></si></sst>',
      'xl/worksheets/sheet1.xml':
          '<worksheet><sheetData>'
          '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>'
          '<row r="2"><c r="A2" t="s"><v>2</v></c><c r="B2" t="s"><v>3</v></c></row>'
          '</sheetData></worksheet>',
    });

    final contacts = parseCustomerImportBytes(xlsxBytes, 'contacts.xlsx');
    expect(contacts, hasLength(1));
    expect(contacts.single.name, 'Lê Hoàng');
    expect(contacts.single.phone, '0988776655');
  });
}
