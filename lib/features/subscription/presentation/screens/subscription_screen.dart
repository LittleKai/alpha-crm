import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/api/crm_cloud_api.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../auth/providers/crm_auth_provider.dart';
import '../../models/subscription_catalog.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isProcessing = false;

  Future<void> _checkout(
    CrmSubscriptionProduct product,
    String paymentMethod,
  ) async {
    setState(() => _isProcessing = true);

    final response = await CrmCloudApi.post('/crm/billing/checkout', {
      'productId': product.productId,
      'paymentMethod': paymentMethod,
    });

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (response['success'] != true) {
      _showSnack(
        response['message']?.toString() ??
            'Không thể tạo giao dịch. Vui lòng thử lại.',
        isError: true,
      );
      return;
    }

    if (paymentMethod == 'credit') {
      await ref.read(crmAuthProvider.notifier).refreshSubscription();
      if (!mounted) return;
      _showSnack(
        product.isPlan
            ? 'Gói Alpha CRM đã được kích hoạt/gia hạn thành công.'
            : 'Đã mua thành công ${product.aiRequests} yêu cầu AI.',
      );
      return;
    }

    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};
    final checkout = CrmCheckoutResult.fromJson(data);
    await _showBankTransferDialog(product, checkout);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.errorText : AppColors.successText,
      ),
    );
  }

  Future<void> _showRenewalConfirmDialog(CrmAuthState authState) async {
    final details = buildRenewalDetails(
      balanceCredits: authState.creditBalance,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AppDialog(
          title: authState.subscriptionStatus == 'active'
              ? 'Xác nhận gia hạn gói tháng'
              : 'Xác nhận đăng ký gói tháng',
          subtitle: 'Kiểm tra chi phí, quota và số dư trước khi tiếp tục.',
          icon: Icons.workspace_premium_rounded,
          width: 560,
          actions: [
            AppDialogAction(
              text: 'Chưa gia hạn',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            AppDialogAction(
              text: 'Tôi xác nhận',
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showCheckoutDialog(crmMonthlyPlan);
              },
            ),
          ],
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'Chi phí',
                      value: '${crmMonthlyPlan.priceCredits} Credits',
                      note: formatVnd(crmMonthlyPlan.priceVnd),
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Quota mới',
                      value: '${crmMonthlyPlan.aiRequests} AI',
                      note: 'Hiệu lực 30 ngày',
                      icon: Icons.auto_awesome_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              ...details.rows.map(
                (row) => _DetailRow(label: row.$1, value: row.$2),
              ),
              const SizedBox(height: AppSpacing.m),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: details.canPayWithCredits
                      ? AppColors.successSoft
                      : AppColors.warningSoft,
                  borderRadius: AppSpacing.borderRadiusM,
                  border: Border.all(
                    color: details.canPayWithCredits
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
                child: Text(
                  details.canPayWithCredits
                      ? 'Số dư hiện tại: ${authState.creditBalance} Credits. Bạn có thể thanh toán bằng Credits ngay.'
                      : 'Số dư hiện tại: ${authState.creditBalance} Credits, thiếu ${details.missingCredits} Credits. Bạn vẫn có thể chọn VietQR.',
                  style: AppTextStyles.body.copyWith(
                    color: details.canPayWithCredits
                        ? AppColors.successText
                        : AppColors.warningText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCheckoutDialog(CrmSubscriptionProduct product) async {
    final authState = ref.read(crmAuthProvider);
    final canPayCredits = authState.creditBalance >= product.priceCredits;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AppDialog(
          title: product.name,
          subtitle: 'Chọn Credits để kích hoạt ngay hoặc VietQR để tạo mã chuyển khoản chính xác.',
          icon: product.isPlan
              ? Icons.workspace_premium_rounded
              : Icons.bolt_rounded,
          width: 520,
          actions: [
            AppDialogAction(
              text: 'Đóng',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
          child: Column(
            children: [
              _DetailRow(
                label: 'Giá trị',
                value:
                    '${formatVnd(product.priceVnd)} hoặc ${product.priceCredits} Credits',
              ),
              _DetailRow(
                label: product.isPlan ? 'Quota gói chính' : 'AI thêm',
                value: '${product.aiRequests} yêu cầu AI',
              ),
              _DetailRow(
                label: 'Số dư Credits',
                value: '${authState.creditBalance} Credits',
              ),
              const SizedBox(height: AppSpacing.m),
              AppButton(
                text: canPayCredits
                    ? 'Thanh toán bằng Credits'
                    : 'Không đủ Credits',
                icon: Icons.account_balance_wallet_rounded,
                width: double.infinity,
                height: 44,
                isLoading: _isProcessing,
                onPressed: canPayCredits && !_isProcessing
                    ? () {
                        Navigator.of(dialogContext).pop();
                        _checkout(product, 'credit');
                      }
                    : null,
              ),
              const SizedBox(height: AppSpacing.s),
              AppButton(
                text: 'Tạo mã VietQR chuyển khoản',
                icon: Icons.qr_code_2_rounded,
                width: double.infinity,
                height: 44,
                variant: AppButtonVariant.outline,
                onPressed: _isProcessing
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        _checkout(product, 'bank_transfer');
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showBankTransferDialog(
    CrmSubscriptionProduct product,
    CrmCheckoutResult checkout,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AppDialog(
          title: 'Mã VietQR chuyển khoản',
          subtitle: 'Quét đúng mã hoặc chuyển khoản đúng nội dung để hệ thống tự duyệt giao dịch.',
          icon: Icons.qr_code_2_rounded,
          width: 560,
          actions: [
            AppDialogAction(
              text: 'Đóng',
              variant: AppButtonVariant.outline,
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(crmAuthProvider.notifier).refreshSubscription();
              },
            ),
            AppDialogAction(
              text: 'Tôi đã chuyển khoản',
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(crmAuthProvider.notifier).refreshSubscription();
                _showSnack(
                  'Đã ghi nhận. Hệ thống sẽ tự duyệt khi tiền về.',
                );
              },
            ),
          ],
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppSpacing.borderRadiusM,
                  border: Border.all(color: AppColors.border),
                ),
                child: checkout.qrCodeUrl == null
                    ? Icon(
                        Icons.qr_code_2_rounded,
                        size: 160,
                        color: AppColors.textSecondary,
                      )
                    : Image.network(
                        checkout.qrCodeUrl!,
                        width: 240,
                        height: 240,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 160,
                              color: AppColors.textSecondary,
                            ),
                      ),
              ),
              const SizedBox(height: AppSpacing.l),
              _DetailRow(label: 'Sản phẩm', value: product.name),
              _DetailRow(
                label: 'Số tiền',
                value: formatVnd(checkout.amountVnd),
              ),
              _DetailRow(
                label: 'Ngân hàng',
                value: checkout.bankName,
              ),
              _DetailRow(
                label: 'Số tài khoản',
                value: checkout.accountNumber,
              ),
              _DetailRow(
                label: 'Chủ tài khoản',
                value: checkout.accountHolder,
              ),
              const SizedBox(height: AppSpacing.s),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppSpacing.borderRadiusM,
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nội dung chuyển khoản',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SelectableText(
                      checkout.transferContent,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    AppButton(
                      text: 'Sao chép nội dung',
                      icon: Icons.copy_rounded,
                      variant: AppButtonVariant.outline,
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(
                            text: checkout.transferContent,
                          ),
                        );
                        _showSnack(
                          'Đã sao chép nội dung chuyển khoản.',
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                'Lưu ý: Không sửa nội dung chuyển khoản. Sau khi ngân hàng ghi nhận đúng mã ${checkout.transferContent}, giao dịch sẽ được tự động duyệt.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.warningText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(crmAuthProvider);
    final isExpired = authState.subscriptionStatus == 'expired';
    final isActive = authState.subscriptionStatus == 'active';

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderSection(
                  status: authState.subscriptionStatus ?? 'none',
                  creditBalance: authState.creditBalance,
                ),
                const SizedBox(height: AppSpacing.l),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 860;
                    final planCard = _buildPlanCard(
                      isActive: isActive,
                      isExpired: isExpired,
                      authState: authState,
                    );
                    final quotaCard = _buildQuotaCard(authState);

                    if (!isWide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          planCard,
                          const SizedBox(height: AppSpacing.l),
                          quotaCard,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: planCard),
                        const SizedBox(width: AppSpacing.l),
                        Expanded(flex: 5, child: quotaCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Gói AI bổ sung', style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSpacing.s),
                Text(
                  'Mua thêm lượt AI khi gói Alpha CRM đang hoạt động. Có thể thanh toán bằng Credits hoặc tạo mã VietQR riêng cho từng gói.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                _buildAiTopUpGrid(isActive),
                const SizedBox(height: AppSpacing.xl),
                _buildPaymentGuide(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required bool isActive,
    required bool isExpired,
    required CrmAuthState authState,
  }) {
    final statusColor = isActive
        ? AppColors.successText
        : isExpired
        ? AppColors.errorText
        : AppColors.warningText;
    final statusBg = isActive
        ? AppColors.successSoft
        : isExpired
        ? AppColors.errorSoft
        : AppColors.warningSoft;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(icon: Icons.workspace_premium_rounded),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gói Alpha CRM hàng tháng',
                      style: AppTextStyles.cardTitle,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Dùng cho Windows Client, Android Connector và các tính năng CRM/Zalo automation.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.s,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: AppSpacing.borderRadiusPill,
                ),
                child: Text(
                  isActive
                      ? 'Đang hoạt động'
                      : isExpired
                      ? 'Đã hết hạn'
                      : 'Chưa đăng ký',
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Wrap(
            spacing: AppSpacing.m,
            runSpacing: AppSpacing.m,
            children: [
              _MetricPill(
                label: 'Chi phí',
                value: '${crmMonthlyPlan.priceCredits} Credits',
                note: formatVnd(crmMonthlyPlan.priceVnd),
              ),
              _MetricPill(
                label: 'Chu kỳ',
                value: '30 ngày',
                note: 'Gia hạn thủ công',
              ),
              _MetricPill(
                label: 'Quota AI',
                value: '${crmMonthlyPlan.aiRequests}',
                note: 'yêu cầu / chu kỳ',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: AppSpacing.borderRadiusM,
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Text(
              isExpired
                  ? 'Gói đã hết hạn. Hãy gia hạn để mở lại gửi tin, chatbot và sử dụng quota AI.'
                  : isActive
                  ? 'Gia hạn sẽ cộng thêm 30 ngày từ hạn hiện tại và đặt lại quota gói chính về 1000 yêu cầu AI.'
                  : 'Đăng ký gói tháng để kích hoạt CRM và bắt đầu kết nối thiết bị.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          AppButton(
            text: isActive ? 'Gia hạn gói tháng' : 'Đăng ký gói tháng',
            icon: Icons.payments_rounded,
            height: 44,
            width: double.infinity,
            isLoading: _isProcessing,
            onPressed: _isProcessing
                ? null
                : () => _showRenewalConfirmDialog(authState),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaCard(CrmAuthState authState) {
    final totalRemaining =
        authState.includedAiRemaining + authState.extraAiRemaining;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(icon: Icons.auto_awesome_rounded),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text(
                  'Hạn mức AI hiện tại',
                  style: AppTextStyles.cardTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Center(
            child: Column(
              children: [
                Text(
                  '$totalRemaining',
                  style: AppTextStyles.pageTitle.copyWith(
                    fontSize: 48,
                    color: totalRemaining > 0
                        ? AppColors.successText
                        : AppColors.errorText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'yêu cầu AI khả dụng',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Row(
            children: [
              Expanded(
                child: _QuotaBucket(
                  label: 'Trong gói tháng',
                  value: authState.includedAiRemaining,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: _QuotaBucket(
                  label: 'Mua thêm',
                  value: authState.extraAiRemaining,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            'Quota mua thêm được giữ lại, nhưng chỉ dùng khi gói Alpha CRM đang hoạt động.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiTopUpGrid(bool hasActivePlan) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 760;
        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: crmAiTopUpPacks.map((product) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.m),
                child: _TopUpCard(
                  product: product,
                  enabled: hasActivePlan && !_isProcessing,
                  onBuy: () => _showCheckoutDialog(product),
                ),
              );
            }).toList(),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: crmAiTopUpPacks.map((product) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: product != crmAiTopUpPacks.last ? AppSpacing.m : 0,
                ),
                child: _TopUpCard(
                  product: product,
                  enabled: hasActivePlan && !_isProcessing,
                  onBuy: () => _showCheckoutDialog(product),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPaymentGuide() {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconBadge(icon: Icons.qr_code_2_rounded),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thanh toán VietQR chính xác',
                  style: AppTextStyles.cardTitle,
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  'Mỗi lần đăng ký/gia hạn hoặc mua gói AI, hãy bấm "Tạo mã VietQR" để hệ thống tạo QR riêng kèm mã giao dịch. Không dùng mã QR tĩnh hoặc nội dung chuyển khoản tự nhập.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                const Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  children: [
                    _GuideChip(text: 'Ngân hàng OCB'),
                    _GuideChip(text: 'Tài khoản CASS55252503'),
                    _GuideChip(text: 'Tự duyệt khi đúng mã CRM'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final String status;
  final int creditBalance;

  const _HeaderSection({required this.status, required this.creditBalance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const _IconBadge(icon: Icons.subscriptions_rounded, size: 56),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đăng ký & gói AI',
                  style: AppTextStyles.pageTitle.copyWith(fontSize: 24),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Quản lý gói Alpha CRM, mua thêm quota AI và tạo mã VietQR chuyển khoản cho từng giao dịch.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Credits', style: AppTextStyles.caption),
              Text(
                '$creditBalance',
                style: AppTextStyles.cardTitle.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                status == 'active'
                    ? 'Gói đang hoạt động'
                    : status == 'expired'
                    ? 'Gói đã hết hạn'
                    : 'Chưa có gói',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;

  const _SurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;

  const _IconBadge({required this.icon, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppSpacing.borderRadiusM,
      ),
      child: Icon(icon, color: AppColors.primary, size: size * 0.52),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final String note;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTextStyles.bodyMedium),
          Text(
            note,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _QuotaBucket extends StatelessWidget {
  final String label;
  final int value;

  const _QuotaBucket({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$value',
            style: AppTextStyles.cardTitle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopUpCard extends StatelessWidget {
  final CrmSubscriptionProduct product;
  final bool enabled;
  final VoidCallback onBuy;

  const _TopUpCard({
    required this.product,
    required this.enabled,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final isPopular = product.productId == 'crm_ai_pack_500';

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(
                icon: isPopular ? Icons.local_fire_department : Icons.bolt,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isPopular
                      ? AppColors.warningSoft
                      : AppColors.primarySoft,
                  borderRadius: AppSpacing.borderRadiusPill,
                ),
                child: Text(
                  product.badge,
                  style: AppTextStyles.caption.copyWith(
                    color: isPopular
                        ? AppColors.warningText
                        : AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Text(product.name, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.s),
          Text(
            '+${product.aiRequests} yêu cầu AI dùng cho chatbot, phân tích khách hàng và soạn chiến dịch.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            formatVnd(product.priceVnd),
            style: AppTextStyles.pageTitle.copyWith(fontSize: 24),
          ),
          Text(
            'hoặc ${product.priceCredits} Credits',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.l),
          AppButton(
            text: enabled ? 'Mua gói này' : 'Cần gói CRM',
            icon: Icons.shopping_cart_checkout_rounded,
            width: double.infinity,
            onPressed: enabled ? onBuy : null,
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final String note;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: AppSpacing.s),
          Text(label, style: AppTextStyles.caption),
          Text(value, style: AppTextStyles.bodyMedium),
          Text(
            note,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _GuideChip extends StatelessWidget {
  final String text;

  const _GuideChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppSpacing.borderRadiusPill,
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
