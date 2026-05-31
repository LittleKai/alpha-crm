import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_alert.dart';
import '../../../../../shared/widgets/app_card.dart';

class AutoApproveScreenPlaceholder extends StatefulWidget {
  const AutoApproveScreenPlaceholder({super.key});

  @override
  State<AutoApproveScreenPlaceholder> createState() =>
      _AutoApproveScreenPlaceholderState();
}

class _AutoApproveScreenPlaceholderState
    extends State<AutoApproveScreenPlaceholder> {
  bool _autoApprove = false;
  bool _sendWelcome = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            const SizedBox(height: AppSpacing.m),
            const AppAlert(
              title: 'Lưu ý — Tự động duyệt kết bạn',
              message:
                  'Tính năng này hoạt động với tài khoản cá nhân. Khi chế độ Official API '
                  'bật, cần đảm bảo tuân thủ chính sách Zalo. Tự động đồng ý kết bạn '
                  'từ người lạ có thể tạo rủi ro bảo mật cho tài khoản.',
              variant: AppAlertVariant.warning,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useColumns = constraints.maxWidth >= 1100;
                  final settings = _SettingsCard(
                    autoApprove: _autoApprove,
                    sendWelcome: _sendWelcome,
                    onAutoApproveChanged: (value) {
                      setState(() {
                        _autoApprove = value;
                      });
                    },
                    onSendWelcomeChanged: (value) {
                      setState(() {
                        _sendWelcome = value;
                      });
                    },
                  );
                  const accounts = _RunningAccountsCard();

                  if (!useColumns) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          settings,
                          const SizedBox(height: AppSpacing.m),
                          SizedBox(height: 320, child: accounts),
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: settings),
                      const SizedBox(width: AppSpacing.l),
                      const Expanded(flex: 5, child: accounts),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_rounded, color: AppColors.primary, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tự động Duyệt lời mời kết bạn',
                style: AppTextStyles.pageTitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Cấu hình tự động đồng ý kết bạn gửi đến và tự động gửi tin nhắn chào mừng.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool autoApprove;
  final bool sendWelcome;
  final ValueChanged<bool> onAutoApproveChanged;
  final ValueChanged<bool> onSendWelcomeChanged;

  const _SettingsCard({
    required this.autoApprove,
    required this.sendWelcome,
    required this.onAutoApproveChanged,
    required this.onSendWelcomeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_rounded,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                'Tự động Duyệt lời mời kết bạn',
                style: AppTextStyles.sectionTitle,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Tính năng này chạy một tiến trình ngầm giúp tự động chấp nhận tất cả các lời mời kết bạn gửi đến các tài khoản Zalo đang kết nối trên ứng dụng.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          _SwitchRow(
            title: 'Trạng thái tự động đồng ý: ĐANG TẮT',
            subtitle: 'Bật tính năng để hệ thống tự động đồng ý kết bạn.',
            value: autoApprove,
            onChanged: onAutoApproveChanged,
          ),
          const SizedBox(height: AppSpacing.m),
          _SwitchRow(
            title: 'Gửi tin nhắn chào mừng khi đồng ý kết bạn: ĐANG TẮT',
            subtitle:
                'Tự động gửi tin nhắn inbox ngay sau khi chấp nhận lời mời kết bạn từ người khác.',
            value: sendWelcome,
            onChanged: onSendWelcomeChanged,
          ),
          const SizedBox(height: AppSpacing.m),
          const AppAlert(
            message:
                'Tính năng hoạt động bằng cách kiểm tra các sự kiện kết bạn thời gian thực (realtime) và quét định kỳ các yêu cầu kết bạn khi tài khoản của bạn đang trực tuyến trên ứng dụng.',
            variant: AppAlertVariant.info,
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _RunningAccountsCard extends StatelessWidget {
  const _RunningAccountsCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tài khoản đang chạy duyệt', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.l),
          RichText(
            text: TextSpan(
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              children: [
                const TextSpan(text: 'Tổng số tài khoản đang đồng bộ: '),
                TextSpan(
                  text: '0 tài khoản',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
