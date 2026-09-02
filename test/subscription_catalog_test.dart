import 'package:alpha_crm/features/subscription/models/subscription_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthly CRM plan matches backend catalog', () {
    expect(crmMonthlyPlan.productId, 'crm_monthly');
    expect(crmMonthlyPlan.priceVnd, 100000);
    expect(crmMonthlyPlan.priceCredits, 1050);
    expect(crmMonthlyPlan.includedAiLimit, 100);
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
    expect(details.missingCredits, 850);
    expect(details.rows, contains(('Hạn mức AI mới', '100 yêu cầu AI')));
    expect(details.rows, contains(('Chi phí', '1050 Credits hoặc 100.000 VND')));
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
        'amountVnd': 100000,
        'credits': 1050,
        'transactionCode': 'CRM123456',
      },
    });

    expect(checkout.qrCodeUrl, contains('vietqr'));
    expect(checkout.transferContent, 'CRM123456');
    expect(checkout.bankName, 'OCB (Phương Đông)');
    expect(checkout.accountNumber, 'CASS55252503');
    expect(checkout.amountVnd, 100000);
  });
}
