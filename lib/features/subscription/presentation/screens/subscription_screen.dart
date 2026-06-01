import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/api/crm_cloud_api.dart';
import '../../../auth/providers/crm_auth_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isAutoRenew = false;
  bool _isProcessing = false;

  Future<void> _purchasePack(int amount, int price) async {
    setState(() {
      _isProcessing = true;
    });

    String productId = 'crm_ai_pack_100';
    if (amount == 500) productId = 'crm_ai_pack_500';
    if (amount == 1000) productId = 'crm_ai_pack_1000';

    // Gọi API nạp thêm gói AI qua cổng thanh toán thực tế của Phase 1
    final response = await CrmCloudApi.post('/crm/billing/checkout', {
      'productId': productId,
      'paymentMethod': 'credit',
    });

    setState(() {
      _isProcessing = false;
    });

    if (mounted) {
      if (response['success'] == true) {
        ref.read(crmAuthProvider.notifier).refreshSubscription();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã mua thành công gói nạp thêm $amount yêu cầu AI!'),
            backgroundColor: AppColors.successText,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Mua gói thất bại. Vui lòng thử lại.'),
            backgroundColor: AppColors.errorText,
          ),
        );
      }
    }
  }

  Future<void> _renewSubscription() async {
    setState(() {
      _isProcessing = true;
    });

    // Gia hạn gói crm_monthly qua cổng thanh toán thực tế của Phase 1
    final response = await CrmCloudApi.post('/crm/billing/checkout', {
      'productId': 'crm_monthly',
      'paymentMethod': 'credit',
    });

    setState(() {
      _isProcessing = false;
    });

    if (mounted) {
      if (response['success'] == true) {
        ref.read(crmAuthProvider.notifier).refreshSubscription();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gia hạn đăng ký dịch vụ thành công!'),
            backgroundColor: AppColors.successText,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Gia hạn thất bại. Vui lòng kiểm tra số dư.'),
            backgroundColor: AppColors.errorText,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(crmAuthProvider);
    final isExpired = authState.subscriptionStatus == 'expired';
    final isActive = authState.subscriptionStatus == 'active';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Đăng Ký & Quản Lý Gói AI',
          style: AppTextStyles.pageTitle.copyWith(fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row chứa gói hiện tại và quota AI
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cột trái: Trạng thái gói
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildPlanStatusCard(isActive, isExpired, authState),
                    ),
                    if (isWide) const SizedBox(width: 24),
                    if (!isWide) const SizedBox(height: 24),
                    // Cột phải: Quota AI
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildAiQuotaCard(authState),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            
            // Phần nạp thêm AI & Gia hạn qua Ngân hàng
            Text(
              'Mua Gói Nạp Thêm AI Quota',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 16),
            _buildAiTopupPackages(),
            const SizedBox(height: 32),
            
            Text(
              'Thanh Toán & Nạp Tiền',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 16),
            _buildBillingInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanStatusCard(bool isActive, bool isExpired, CrmAuthState authState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gói Dịch Vụ CRM',
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.successSoft
                        : (isExpired ? AppColors.errorSoft : AppColors.warningSoft),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive
                        ? 'Đang hoạt động'
                        : (isExpired ? 'Đã hết hạn' : 'Chưa đăng ký'),
                    style: AppTextStyles.caption.copyWith(
                      color: isActive
                          ? AppColors.successText
                          : (isExpired ? AppColors.errorText : AppColors.warningText),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildPlanDetailRow('Mức Giá:', '200,000 VND / tháng (hoặc 210 credits)'),
            _buildPlanDetailRow('Thời Hạn:', 'Hằng tháng (Gia hạn thủ công mặc định)'),
            _buildPlanDetailRow('Trạng Thái Hệ Thống:', isExpired ? 'Chế độ Đọc-Chỉ-Xem (Read-Only) đang kích hoạt' : 'Hoạt động đầy đủ tính năng'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Gia Hạn Dịch Vụ'),
                                content: const Text('Hệ thống sẽ trừ 210 Credits từ số dư tài khoản của bạn để gia hạn gói CRM 1 tháng. Bạn có muốn tiếp tục?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Hủy'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _renewSubscription();
                                    },
                                    child: const Text('Xác Nhận'),
                                  ),
                                ],
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isProcessing
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Gia Hạn Bằng Credits (210đ)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Switch(
                  value: _isAutoRenew,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      _isAutoRenew = val;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tự động gia hạn từ Credits khi hết chu kỳ',
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiQuotaCard(CrmAuthState authState) {
    final totalRemaining = authState.includedAiRemaining + authState.extraAiRemaining;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hạn Mức AI (Quota)',
              style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Text(
                    '$totalRemaining',
                    style: AppTextStyles.pageTitle.copyWith(
                      fontSize: 48,
                      color: totalRemaining > 0 ? AppColors.successText : AppColors.errorText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Yêu cầu AI còn lại',
                    style: AppTextStyles.caption.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildQuotaInfoSub('Bao gồm trong gói:', '${authState.includedAiRemaining}'),
                Container(width: 1, height: 32, color: AppColors.border),
                _buildQuotaInfoSub('Nạp thêm ngoài gói:', '${authState.extraAiRemaining}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaInfoSub(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, fontSize: 15)),
      ],
    );
  }

  Widget _buildAiTopupPackages() {
    final packages = [
      {'amount': 100, 'price': 50, 'badge': 'Tiết kiệm'},
      {'amount': 500, 'price': 200, 'badge': 'Phổ biến'},
      {'amount': 1000, 'price': 350, 'badge': 'Ưu đãi lớn'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return Flex(
          direction: isWide ? Axis.horizontal : Axis.vertical,
          children: packages.map((pkg) {
            final card = Card(
              color: AppColors.surfaceMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.border.withOpacity(0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        pkg['badge'] as String,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '+${pkg['amount']} AI Requests',
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${pkg['price']} Credits',
                      style: AppTextStyles.pageTitle.copyWith(
                        fontSize: 22,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => _purchasePack(pkg['amount'] as int, pkg['price'] as int),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Mua Ngay'),
                    ),
                  ],
                ),
              ),
            );

            return Expanded(
              flex: isWide ? 1 : 0,
              child: Padding(
                padding: EdgeInsets.only(
                  right: isWide ? 16.0 : 0,
                  bottom: isWide ? 0 : 16.0,
                ),
                child: card,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBillingInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // QR hoặc Bank Logo
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.slateSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 64, color: AppColors.textSecondary),
                        SizedBox(height: 8),
                        Text('Quét mã chuyển khoản', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
                if (isWide) const SizedBox(width: 32),
                if (!isWide) const SizedBox(height: 24),
                
                // Bank Details
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chuyển Khoản Ngân Hàng (24/7)',
                        style: AppTextStyles.cardTitle,
                      ),
                      const SizedBox(height: 12),
                      _buildBankDetail('Ngân hàng:', 'MB Bank (Ngân hàng Quân Đội)'),
                      _buildBankDetail('Số tài khoản:', '9999-8888-6666-999'),
                      _buildBankDetail('Chủ tài khoản:', 'CONG TY COPH AN ALPHA STUDIO'),
                      _buildBankDetail('Nội dung chuyển khoản:', 'ALPHA CRM <Email của bạn>'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '⚠️ Lưu ý: Tỷ giá nạp Credits là 1,000 VND = 1 Credit. Hệ thống sẽ tự động duyệt giao dịch chuyển khoản trong vòng 2-5 phút.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.warningText, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBankDetail(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
          Expanded(child: Text(val, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontSize: 13))),
        ],
      ),
    );
  }
}
