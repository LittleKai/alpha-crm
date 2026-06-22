import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_alert.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../providers/auto_approve_provider.dart';

class AutoApproveScreen extends ConsumerStatefulWidget {
  const AutoApproveScreen({super.key});

  @override
  ConsumerState<AutoApproveScreen> createState() => _AutoApproveScreenState();
}

class _AutoApproveScreenState extends ConsumerState<AutoApproveScreen> {
  final _welcomeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(zaloIntegrationProvider.notifier).checkConnection();
      _welcomeController.text = ref.read(autoApproveProvider).welcomeMessage;
    });
  }

  @override
  void dispose() {
    _welcomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(autoApproveProvider);
    final notifier = ref.read(autoApproveProvider.notifier);
    final zaloState = ref.watch(zaloIntegrationProvider);
    final activeAccounts = zaloState.accounts;
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useColumns = constraints.maxWidth >= 1100;
                  final leftCard = _buildSettingsCard(state, notifier);
                  final rightCard = _buildRunningAccountsCard(
                    state,
                    activeAccounts,
                  );

                  if (!useColumns) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          leftCard,
                          const SizedBox(height: AppSpacing.m),
                          SizedBox(height: 320, child: rightCard),
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: leftCard),
                      const SizedBox(width: AppSpacing.l),
                      Expanded(flex: 5, child: rightCard),
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

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.check_rounded, color: AppColors.primary, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tự động Duyệt kết bạn', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Cấu hình đồng ý lời mời kết bạn gửi đến và tự động chào mừng.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(
    AutoApproveState state,
    AutoApproveNotifier notifier,
  ) {
    return AppCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: state.autoApprove
                      ? AppColors.success
                      : AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s),
                Text(
                  'Tự động duyệt kết bạn',
                  style: AppTextStyles.sectionTitle,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              'Tiến trình ngầm sẽ tự động chấp nhận tất cả lời mời kết bạn gửi tới các tài khoản Zalo đang trực tuyến trên ứng dụng.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            _buildSwitchRow(
              title:
                  'Tự động duyệt kết bạn: ${state.autoApprove ? "ĐANG BẬT" : "ĐANG TẮT"}',
              subtitle: 'Hệ thống tự động đồng ý kết bạn gửi đến.',
              value: state.autoApprove,
              onChanged: notifier.toggleAutoApprove,
            ),
            const SizedBox(height: AppSpacing.m),
            _buildSwitchRow(
              title:
                  'Gửi inbox chào mừng: ${state.sendWelcome ? "ĐANG BẬT" : "ĐANG TẮT"}',
              subtitle:
                  'Gửi tin nhắn chào mừng ngay sau khi chấp nhận lời mời.',
              value: state.sendWelcome,
              onChanged: notifier.toggleSendWelcome,
            ),
            if (state.sendWelcome) ...[
              const SizedBox(height: AppSpacing.m),
              Text('Nội dung tin nhắn chào mừng *', style: AppTextStyles.label),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _welcomeController,
                maxLines: 3,
                style: AppTextStyles.body,
                onChanged: notifier.updateWelcomeMessage,
                decoration: const InputDecoration(
                  hintText: 'Cảm ơn bạn đã kết bạn! Rất vui được làm quen.',
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.l),
            const AppAlert(
              message:
                  'Tiến trình ngầm sẽ lắng nghe các sự kiện kết bạn thời gian thực (realtime) từ Zalo để duyệt lời mời kết bạn ngay lập tức khi tài khoản đang kết nối trực tuyến.',
              variant: AppAlertVariant.info,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
        borderRadius: AppSpacing.borderRadiusM,
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

  Widget _buildRunningAccountsCard(
    AutoApproveState state,
    List<ZaloConnectedAccount> accounts,
  ) {
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
                  text: '${accounts.length} tài khoản',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          if (accounts.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Chưa có tài khoản nào kết nối.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: accounts.length,
                separatorBuilder: (context, index) =>
                    Divider(color: AppColors.borderSoft),
                itemBuilder: (context, index) {
                  final acc = accounts[index];
                  final cleanLabel = acc.label.replaceAll(
                    RegExp(r'\s*\([^)]*\)$'),
                    '',
                  );
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.surfaceMuted,
                      backgroundImage: acc.avatarUrl.isNotEmpty
                          ? NetworkImage(acc.avatarUrl)
                          : null,
                      child: acc.avatarUrl.isEmpty
                          ? Text(
                              cleanLabel.isNotEmpty
                                  ? cleanLabel[0].toUpperCase()
                                  : 'A',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      cleanLabel,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Đang lắng nghe sự kiện kết bạn...',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.sync,
                      color: AppColors.success,
                      size: 18,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
