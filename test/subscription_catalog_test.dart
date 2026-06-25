import 'package:alpha_crm/features/subscription/models/subscription_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthly CRM plan matches backend catalog', () {
    expect(crmMonthlyPlan.productId, 'crm_monthly');
    expect(crmMonthlyPlan.priceVnd, 500000);
    expect(crmMonthlyPlan.priceCredits, 5250);
    expect(crmMonthlyPlan.includedAiLimit, 1000);
  });

  test('AI top-up packs match backend catalog', () {
    expect(crmAiTopUpPacks.map((pack) => pack.productId), [
      'crm_ai_pack_100',
      'crm_ai_pack_500',
      'crm_ai_pack_1000',
    ]);
    expect(crmAiTopUpPacks.map((pack) => pack.aiRequests), [200, 1000, 2000]);
    expect(crmAiTopUpPacks.map((pack) => pack.priceCredits), [500, 2000, 3500]);
  });

  test('renewal details identify missing credits', () {
    final details = buildRenewalDetails(balanceCredits: 200);

    expect(details.canPayWithCredits, isFalse);
    expect(details.missingCredits, 5050);
    expect(details.rows, contains(('Hạn mức AI mới', '1000 yêu cầu AI')));
  });

  test('parses bank transfer checkout response', () {
    final checkout = CrmCheckoutResult.fromJson({
      'qrCodeUrl': 'https://img.vietqr.io/image/OCB-CASS55252503.png',
      'transferContent': 'CRM123456',
      'bankInfo': {
        'bankName': 'OCB (Phương Đông)',
        'accountNumber': 'CASS55252503',
        'accountHolder': 'NGUYEN ANH DUC',
      },
      'order': {
        'amountVnd': 500000,
        'credits': 5250,
        'transactionCode': 'CRM123456',
      },
    });

    expect(checkout.qrCodeUrl, contains('vietqr'));
    expect(checkout.transferContent, 'CRM123456');
    expect(checkout.bankName, 'OCB (Phương Đông)');
    expect(checkout.accountNumber, 'CASS55252503');
    expect(checkout.amountVnd, 500000);
  });
}
