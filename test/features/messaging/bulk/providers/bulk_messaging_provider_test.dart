import 'package:alpha_crm/features/messaging/bulk/providers/bulk_messaging_provider.dart';
import 'package:alpha_crm/mock/mock_campaigns.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const acc1 = ZaloAccount(
    id: 'acc-1',
    name: 'Tài khoản 1',
    phone: 'acc-1',
    type: 'Cá nhân',
    isConnected: true,
  );
  const acc2 = ZaloAccount(
    id: 'acc-2',
    name: 'Tài khoản 2',
    phone: 'acc-2',
    type: 'Cá nhân',
    isConnected: true,
  );

  test('copyWith can clear selected account', () {
    final state = BulkMessagingState.initial().copyWith(selectedAccount: acc1);

    expect(state.selectedAccount, acc1);
    expect(state.copyWith(selectedAccount: null).selectedAccount, isNull);
  });

  test('resolves selected account after account list refresh', () {
    expect(resolveBulkSelectedAccountForTest(acc2, [acc1, acc2]), same(acc2));

    expect(
      resolveBulkSelectedAccountForTest(
        const ZaloAccount(
          id: bulkAllAccountsId,
          name: 'Toàn bộ tài khoản',
          phone: '',
          type: 'all',
        ),
        [acc1, acc2],
      )?.id,
      bulkAllAccountsId,
    );

    expect(resolveBulkSelectedAccountForTest(acc2, [acc1]), acc1);
    expect(resolveBulkSelectedAccountForTest(acc1, []), isNull);
  });

  test('maps all accounts selection to empty child provider filter', () {
    expect(bulkAccountFilterIdForTest(null), '');
    expect(bulkAccountFilterIdForTest(acc1), 'acc-1');
    expect(
      bulkAccountFilterIdForTest(
        const ZaloAccount(
          id: bulkAllAccountsId,
          name: 'Toàn bộ tài khoản',
          phone: '',
          type: 'all',
        ),
      ),
      '',
    );
  });
}
