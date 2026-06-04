import 'package:alpha_crm/features/customers/data/customers_repository.dart';
import 'package:alpha_crm/features/customers/data/segments_repository.dart';
import 'package:alpha_crm/features/customers/presentation/screens/customers_screen.dart';
import 'package:alpha_crm/features/customers/providers/customers_provider.dart';
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
}
