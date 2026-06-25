class CrmSubscriptionProduct {
  final String productId;
  final String name;
  final int priceVnd;
  final int priceCredits;
  final int aiRequests;
  final String badge;
  final bool isPlan;

  const CrmSubscriptionProduct({
    required this.productId,
    required this.name,
    required this.priceVnd,
    required this.priceCredits,
    required this.aiRequests,
    required this.badge,
    required this.isPlan,
  });

  int get includedAiLimit => isPlan ? aiRequests : 0;
}

class RenewalDetails {
  final bool canPayWithCredits;
  final int missingCredits;
  final List<(String, String)> rows;

  const RenewalDetails({
    required this.canPayWithCredits,
    required this.missingCredits,
    required this.rows,
  });
}

class CrmCheckoutResult {
  final String? qrCodeUrl;
  final String transferContent;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final int amountVnd;
  final int credits;
  final String transactionCode;

  const CrmCheckoutResult({
    required this.qrCodeUrl,
    required this.transferContent,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    required this.amountVnd,
    required this.credits,
    required this.transactionCode,
  });

  factory CrmCheckoutResult.fromJson(Map<String, dynamic> json) {
    final bankInfo = json['bankInfo'] is Map
        ? Map<String, dynamic>.from(json['bankInfo'] as Map)
        : <String, dynamic>{};
    final order = json['order'] is Map
        ? Map<String, dynamic>.from(json['order'] as Map)
        : <String, dynamic>{};
    final transactionCode = order['transactionCode']?.toString() ?? '';

    return CrmCheckoutResult(
      qrCodeUrl: json['qrCodeUrl']?.toString(),
      transferContent: json['transferContent']?.toString() ?? transactionCode,
      bankName: bankInfo['bankName']?.toString() ?? 'OCB (Phương Đông)',
      accountNumber: bankInfo['accountNumber']?.toString() ?? 'CASS55252503',
      accountHolder: bankInfo['accountHolder']?.toString() ?? 'NGUYEN ANH DUC',
      amountVnd: _asInt(order['amountVnd'] ?? order['amount']),
      credits: _asInt(order['credits']),
      transactionCode: transactionCode,
    );
  }
}

const crmTrialPlan = CrmSubscriptionProduct(
  productId: 'crm_trial',
  name: 'Gói dùng thử Alpha CRM',
  priceVnd: 0,
  priceCredits: 0,
  aiRequests: 100,
  badge: 'Dùng thử',
  isPlan: true,
);

const crmMonthlyPlan = CrmSubscriptionProduct(
  productId: 'crm_monthly',
  name: 'Gói Alpha CRM hàng tháng',
  priceVnd: 500000,
  priceCredits: 5250,
  aiRequests: 1000,
  badge: 'Gói chính',
  isPlan: true,
);

const crmAiTopUpPacks = [
  CrmSubscriptionProduct(
    productId: 'crm_ai_pack_100',
    name: 'Gói AI Top-up 200',
    priceVnd: 50000,
    priceCredits: 500,
    aiRequests: 200,
    badge: 'Tiết kiệm',
    isPlan: false,
  ),
  CrmSubscriptionProduct(
    productId: 'crm_ai_pack_500',
    name: 'Gói AI Top-up 1000',
    priceVnd: 200000,
    priceCredits: 2000,
    aiRequests: 1000,
    badge: 'Phổ biến',
    isPlan: false,
  ),
  CrmSubscriptionProduct(
    productId: 'crm_ai_pack_1000',
    name: 'Gói AI Top-up 2000',
    priceVnd: 350000,
    priceCredits: 3500,
    aiRequests: 2000,
    badge: 'Ưu đãi lớn',
    isPlan: false,
  ),
];

RenewalDetails buildRenewalDetails({required int balanceCredits}) {
  final missingCredits = (crmMonthlyPlan.priceCredits - balanceCredits).clamp(
    0,
    crmMonthlyPlan.priceCredits,
  );

  return RenewalDetails(
    canPayWithCredits: missingCredits == 0,
    missingCredits: missingCredits,
    rows: const [
      ('Gói gia hạn', 'Alpha CRM 1 tháng'),
      ('Chi phí', '5250 Credits hoặc 500.000 VND'),
      ('Hạn mức AI mới', '1000 yêu cầu AI'),
      ('Hiệu lực', 'Gia hạn thêm 30 ngày và đặt lại quota gói chính'),
    ],
  );
}

String formatVnd(int amount) {
  final text = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(text[i]);
  }
  return '$bufferđ';
}

int _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
