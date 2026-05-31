import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../mock/mock_accounts.dart';
import '../../providers/settings_provider.dart';
import '../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../widgets/zalo_compliance_help_panel.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _proxyController = TextEditingController();
  final _minDelayController = TextEditingController();
  final _maxDelayController = TextEditingController();
  final _chatbotDelayController = TextEditingController(text: '5');
  final _backendUrlController = TextEditingController();
  final _batchSizeController = TextEditingController();
  final _dailyLimitController = TextEditingController();
  final _cooldownController = TextEditingController();
  final _approvalThresholdController = TextEditingController();
  final _failureRateController = TextEditingController();
  final _stopReportController = TextEditingController();
  final _quietStartController = TextEditingController();
  final _quietEndController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider).settings;
      _proxyController.text = settings.proxy;
      _minDelayController.text = settings.minDelay.toString();
      _maxDelayController.text = settings.maxDelay.toString();
      _backendUrlController.text = settings.zaloBackendBaseUrl;
      _batchSizeController.text = settings.maxBatchSize.toString();
      _dailyLimitController.text = settings.dailySendLimit.toString();
      _cooldownController.text = settings.perRecipientCooldownHours.toString();
      _approvalThresholdController.text =
          settings.humanApprovalThreshold.toString();
      _failureRateController.text = settings.maxFailureRatePercent.toString();
      _stopReportController.text = settings.stopOnReportCount.toString();
      _quietStartController.text = settings.quietHoursStart;
      _quietEndController.text = settings.quietHoursEnd;
    });
  }

  @override
  void dispose() {
    _proxyController.dispose();
    _minDelayController.dispose();
    _maxDelayController.dispose();
    _chatbotDelayController.dispose();
    _backendUrlController.dispose();
    _batchSizeController.dispose();
    _dailyLimitController.dispose();
    _cooldownController.dispose();
    _approvalThresholdController.dispose();
    _failureRateController.dispose();
    _stopReportController.dispose();
    _quietStartController.dispose();
    _quietEndController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final connectedCount = state.accounts
        .where((account) => account.isConnected)
        .length;

    if (state.isSaved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã lưu cài đặt.')));
        notifier.resetSavedState();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: AppSpacing.l),
            _AccountCard(
              proxyController: _proxyController,
              connectedCount: connectedCount,
              onProxyChanged: notifier.updateProxy,
              onAddAccount: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chưa triển khai đăng nhập QR thật.'),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.m),
            _TimeSettingsCard(
              minDelayController: _minDelayController,
              maxDelayController: _maxDelayController,
              chatbotDelayController: _chatbotDelayController,
              isLoading: state.isLoading,
              errorText: state.errorText,
              onMinDelayChanged: (value) =>
                  notifier.updateMinDelay(int.tryParse(value) ?? 0),
              onMaxDelayChanged: (value) =>
                  notifier.updateMaxDelay(int.tryParse(value) ?? 0),
              onSave: notifier.saveSettings,
            ),
            const SizedBox(height: AppSpacing.m),
            _ZaloIntegrationCard(
              backendUrlController: _backendUrlController,
              webhookPath: state.settings.zaloWebhookPath,
              onBackendUrlChanged: notifier.updateZaloBackendBaseUrl,
            ),
            const SizedBox(height: AppSpacing.m),
            _RiskControlsCard(
              settings: state.settings,
              batchSizeController: _batchSizeController,
              dailyLimitController: _dailyLimitController,
              cooldownController: _cooldownController,
              approvalThresholdController: _approvalThresholdController,
              failureRateController: _failureRateController,
              stopReportController: _stopReportController,
              quietStartController: _quietStartController,
              quietEndController: _quietEndController,
              isLoading: state.isLoading,
              onChannelModeChanged: notifier.updateZaloChannelMode,
              onPersonalAutomationChanged: notifier.updateAllowPersonalAccountAutomation,
              onProxyUsageChanged: notifier.updateAllowProxyUsage,
              onFriendAutomationChanged: notifier.updateAllowFriendAutomation,
              onGroupAutomationChanged: notifier.updateAllowGroupAutomation,
              onRequireConsentChanged: notifier.updateRequireConsentProof,
              onRequireInteractionChanged:
                  notifier.updateRequireRecentInteraction,
              onDisableSpintaxChanged: notifier.updateDisableSpintax,
              onRequireHumanApprovalChanged:
                  notifier.updateRequireHumanApproval,
              onBatchSizeChanged: (v) =>
                  notifier.updateMaxBatchSize(int.tryParse(v) ?? 20),
              onDailyLimitChanged: (v) =>
                  notifier.updateDailySendLimit(int.tryParse(v) ?? 100),
              onCooldownChanged: (v) =>
                  notifier.updatePerRecipientCooldownHours(
                      int.tryParse(v) ?? 24),
              onApprovalThresholdChanged: (v) =>
                  notifier.updateHumanApprovalThreshold(
                      int.tryParse(v) ?? 20),
              onFailureRateChanged: (v) =>
                  notifier.updateMaxFailureRatePercent(
                      int.tryParse(v) ?? 10),
              onStopReportChanged: (v) =>
                  notifier.updateStopOnReportCount(int.tryParse(v) ?? 1),
              onQuietStartChanged: notifier.updateQuietHoursStart,
              onQuietEndChanged: notifier.updateQuietHoursEnd,
              onSave: notifier.saveSettings,
            ),
            const SizedBox(height: AppSpacing.m),
            const ZaloComplianceHelpPanel(),
            const SizedBox(height: AppSpacing.m),
            _AdvancedCard(
              enabled: state.settings.autoApproveFriend,
              isLoading: state.isLoading,
              onChanged: notifier.updateAutoApproveFriend,
              onSave: notifier.saveSettings,
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
        const Icon(Icons.settings_outlined, color: AppColors.primary, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cài Đặt', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Quản lý tài khoản Zalo và cấu hình ứng dụng',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  final TextEditingController proxyController;
  final int connectedCount;
  final ValueChanged<String> onProxyChanged;
  final VoidCallback onAddAccount;

  const _AccountCard({
    required this.proxyController,
    required this.connectedCount,
    required this.onProxyChanged,
    required this.onAddAccount,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_none_outlined, size: 20),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  'Tài khoản Zalo',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              AppBadge(
                label: '$connectedCount đang kết nối',
                variant: connectedCount > 0
                    ? AppBadgeVariant.success
                    : AppBadgeVariant.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            'Kết nối nhiều tài khoản Zalo đồng thời. Mỗi tài khoản quét QR riêng, lưu phiên riêng, hoạt động độc lập.',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            'Proxy cho tài khoản mới (Tùy chọn)',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: proxyController,
            style: AppTextStyles.body,
            onChanged: onProxyChanged,
            decoration: const InputDecoration(
              hintText: 'VD: http://ip:port hoặc socks5://user:pass@ip:port',
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              text: 'Thêm tài khoản Zalo',
              icon: Icons.add,
              onPressed: onAddAccount,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeSettingsCard extends StatelessWidget {
  final TextEditingController minDelayController;
  final TextEditingController maxDelayController;
  final TextEditingController chatbotDelayController;
  final bool isLoading;
  final String? errorText;
  final ValueChanged<String> onMinDelayChanged;
  final ValueChanged<String> onMaxDelayChanged;
  final VoidCallback onSave;

  const _TimeSettingsCard({
    required this.minDelayController,
    required this.maxDelayController,
    required this.chatbotDelayController,
    required this.isLoading,
    this.errorText,
    required this.onMinDelayChanged,
    required this.onMaxDelayChanged,
    required this.onSave,
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
                Icons.access_time_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const Spacer(),
              Text('Cài đặt thời gian', style: AppTextStyles.sectionTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 720;
              final fields = [
                _NumberInput(
                  label: 'Delay tối thiểu (giây)',
                  controller: minDelayController,
                  onChanged: onMinDelayChanged,
                ),
                _NumberInput(
                  label: 'Delay tối đa (giây)',
                  controller: maxDelayController,
                  onChanged: onMaxDelayChanged,
                ),
              ];

              if (stack) {
                return Column(
                  children: [
                    fields[0],
                    const SizedBox(height: AppSpacing.m),
                    fields[1],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(child: fields[1]),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            width: 220,
            child: _NumberInput(
              label: 'Delay chatbot trả lời (giây)',
              controller: chatbotDelayController,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          const AppAlert(
            message:
                'Delay ngẫu nhiên 30-60s giúp hành vi giống người thật, tránh bị hạn chế tài khoản.',
            variant: AppAlertVariant.warning,
          ),
          if (errorText != null) ...[
            const SizedBox(height: AppSpacing.s),
            AppAlert(message: errorText!, variant: AppAlertVariant.error),
          ],
          const SizedBox(height: AppSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              text: 'Lưu cài đặt',
              icon: Icons.save_outlined,
              isLoading: isLoading,
              onPressed: onSave,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZaloIntegrationCard extends ConsumerWidget {
  final TextEditingController backendUrlController;
  final String webhookPath;
  final ValueChanged<String> onBackendUrlChanged;

  const _ZaloIntegrationCard({
    required this.backendUrlController,
    required this.webhookPath,
    required this.onBackendUrlChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final integrationState = ref.watch(zaloIntegrationProvider);
    final integrationNotifier = ref.read(zaloIntegrationProvider.notifier);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  'Tích hợp Zalo Backend',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              AppBadge(
                label: integrationState.isConnected
                    ? 'Đã kết nối'
                    : 'Chưa kết nối',
                variant: integrationState.isConnected
                    ? AppBadgeVariant.success
                    : AppBadgeVariant.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          const AppAlert(
            message:
                'Flutter kết nối tới Node.js service qua HTTP. Token Zalo được lưu trữ '
                'an toàn trên backend, không lộ ra phía client.',
            variant: AppAlertVariant.info,
          ),
          const SizedBox(height: AppSpacing.m),
          Text('Backend URL', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: backendUrlController,
            style: AppTextStyles.body,
            onChanged: onBackendUrlChanged,
            decoration: const InputDecoration(
              hintText: 'http://localhost:8787',
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Text('Webhook path: ', style: AppTextStyles.label),
              Text(
                webhookPath,
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          if (integrationState.isConnected) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: AppSpacing.borderRadiusM,
                border: Border.all(color: AppColors.success),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service v${integrationState.serviceVersion ?? "?"}  •  Mode: ${integrationState.mode}',
                    style: AppTextStyles.bodyMedium,
                  ),
                  if (integrationState.accountType != null)
                    Text(
                      'Account: ${integrationState.accountLabel ?? integrationState.accountType} (${integrationState.accountType})',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  if (integrationState.listenerRunning)
                    Text(
                      'Listener: đang chạy',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  if (integrationState.lastEventAt != null)
                    Text(
                      'Last event: ${integrationState.lastEventAt}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ] else if (integrationState.errorText != null) ...[
            AppAlert(
              message: integrationState.errorText!,
              variant: AppAlertVariant.error,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.appBackground,
                borderRadius: AppSpacing.borderRadiusM,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      'Nhấn "Kiểm tra kết nối" để kiểm tra trạng thái backend.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              text: 'Kiểm tra kết nối',
              icon: Icons.refresh,
              isLoading: integrationState.isLoading,
              onPressed: integrationNotifier.checkConnection,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskControlsCard extends StatelessWidget {
  final SystemSettings settings;
  final TextEditingController batchSizeController;
  final TextEditingController dailyLimitController;
  final TextEditingController cooldownController;
  final TextEditingController approvalThresholdController;
  final TextEditingController failureRateController;
  final TextEditingController stopReportController;
  final TextEditingController quietStartController;
  final TextEditingController quietEndController;
  final bool isLoading;
  final ValueChanged<ZaloChannelMode> onChannelModeChanged;
  final ValueChanged<bool> onPersonalAutomationChanged;
  final ValueChanged<bool> onProxyUsageChanged;
  final ValueChanged<bool> onFriendAutomationChanged;
  final ValueChanged<bool> onGroupAutomationChanged;
  final ValueChanged<bool> onRequireConsentChanged;
  final ValueChanged<bool> onRequireInteractionChanged;
  final ValueChanged<bool> onDisableSpintaxChanged;
  final ValueChanged<bool> onRequireHumanApprovalChanged;
  final ValueChanged<String> onBatchSizeChanged;
  final ValueChanged<String> onDailyLimitChanged;
  final ValueChanged<String> onCooldownChanged;
  final ValueChanged<String> onApprovalThresholdChanged;
  final ValueChanged<String> onFailureRateChanged;
  final ValueChanged<String> onStopReportChanged;
  final ValueChanged<String> onQuietStartChanged;
  final ValueChanged<String> onQuietEndChanged;
  final VoidCallback onSave;

  const _RiskControlsCard({
    required this.settings,
    required this.batchSizeController,
    required this.dailyLimitController,
    required this.cooldownController,
    required this.approvalThresholdController,
    required this.failureRateController,
    required this.stopReportController,
    required this.quietStartController,
    required this.quietEndController,
    required this.isLoading,
    required this.onChannelModeChanged,
    required this.onPersonalAutomationChanged,
    required this.onProxyUsageChanged,
    required this.onFriendAutomationChanged,
    required this.onGroupAutomationChanged,
    required this.onRequireConsentChanged,
    required this.onRequireInteractionChanged,
    required this.onDisableSpintaxChanged,
    required this.onRequireHumanApprovalChanged,
    required this.onBatchSizeChanged,
    required this.onDailyLimitChanged,
    required this.onCooldownChanged,
    required this.onApprovalThresholdChanged,
    required this.onFailureRateChanged,
    required this.onStopReportChanged,
    required this.onQuietStartChanged,
    required this.onQuietEndChanged,
    required this.onSave,
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
                Icons.security_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  'Kiểm soát rủi ro Zalo',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),

          // Active safety switches
          _ChannelModeRow(
            currentMode: settings.zaloChannelMode,
            onChanged: (mode) {
              if (mode != null) {
                onChannelModeChanged(mode);
              }
            },
          ),
          _SwitchRow(
            label: 'Yêu cầu bằng chứng đồng ý',
            subtitle:
                'Không gửi tin nhắn nếu chưa có consent proof từ người nhận.',
            value: settings.requireConsentProof,
            onChanged: onRequireConsentChanged,
          ),
          _SwitchRow(
            label: 'Yêu cầu tương tác gần đây',
            subtitle:
                'Chỉ gửi khi người nhận đã tương tác với OA/Bot trong khoảng thời gian cho phép.',
            value: settings.requireRecentInteraction,
            onChanged: onRequireInteractionChanged,
          ),
          _SwitchRow(
            label: 'Tắt Spintax',
            subtitle: 'Không cho phép xoay vòng nội dung tin nhắn.',
            value: settings.disableSpintax,
            onChanged: onDisableSpintaxChanged,
          ),
          _SwitchRow(
            label: 'Yêu cầu duyệt thủ công',
            subtitle:
                'Chiến dịch vượt ngưỡng số lượng cần được duyệt trước khi gửi.',
            value: settings.requireHumanApproval,
            onChanged: onRequireHumanApprovalChanged,
          ),

          const Divider(height: AppSpacing.l),

          // Disabled unsafe toggles
          _DisabledSwitchRow(
            label: 'Tự động hóa tài khoản cá nhân',
            subtitle: settings.zaloChannelMode == ZaloChannelMode.officialOa
                ? 'Bị vô hiệu khi kênh Official OA đang chọn.'
                : 'Cho phép tự động hóa qua personal Zalo (zca-js).',
            value: settings.allowPersonalAccountAutomation,
            isDisabled: settings.zaloChannelMode == ZaloChannelMode.officialOa,
            onChanged: onPersonalAutomationChanged,
          ),
          _DisabledSwitchRow(
            label: 'Sử dụng Proxy',
            subtitle:
                'Bị vô hiệu khi Official OA bật. Proxy có thể bị nhận diện là hành vi né tránh.',
            value: settings.allowProxyUsage,
            isDisabled: settings.zaloChannelMode == ZaloChannelMode.officialOa,
            onChanged: onProxyUsageChanged,
          ),
          _DisabledSwitchRow(
            label: 'Tự động kết bạn',
            subtitle:
                'Bị vô hiệu khi Official OA bật. Gửi lời mời kết bạn hàng loạt là rủi ro cao.',
            value: settings.allowFriendAutomation,
            isDisabled: settings.zaloChannelMode == ZaloChannelMode.officialOa,
            onChanged: onFriendAutomationChanged,
          ),
          _DisabledSwitchRow(
            label: 'Tự động nhóm',
            subtitle:
                'Bị vô hiệu khi Official OA bật. Tham gia/tạo/mời nhóm tự động là rủi ro cao.',
            value: settings.allowGroupAutomation,
            isDisabled: settings.zaloChannelMode == ZaloChannelMode.officialOa,
            onChanged: onGroupAutomationChanged,
          ),

          const Divider(height: AppSpacing.l),

          // Numeric fields
          Text(
            'Giới hạn & Ngưỡng',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.m),

          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 720;
              if (stack) {
                return Column(
                  children: [
                    _NumberInput(
                      label: 'Batch size tối đa',
                      controller: batchSizeController,
                      onChanged: onBatchSizeChanged,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _NumberInput(
                      label: 'Giới hạn gửi/ngày',
                      controller: dailyLimitController,
                      onChanged: onDailyLimitChanged,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _NumberInput(
                      label: 'Cooldown/người nhận (giờ)',
                      controller: cooldownController,
                      onChanged: onCooldownChanged,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _NumberInput(
                      label: 'Ngưỡng duyệt thủ công',
                      controller: approvalThresholdController,
                      onChanged: onApprovalThresholdChanged,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _NumberInput(
                      label: 'Tỷ lệ lỗi tối đa (%)',
                      controller: failureRateController,
                      onChanged: onFailureRateChanged,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _NumberInput(
                      label: 'Dừng khi bị báo cáo (lần)',
                      controller: stopReportController,
                      onChanged: onStopReportChanged,
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _NumberInput(
                          label: 'Batch size tối đa',
                          controller: batchSizeController,
                          onChanged: onBatchSizeChanged,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: _NumberInput(
                          label: 'Giới hạn gửi/ngày',
                          controller: dailyLimitController,
                          onChanged: onDailyLimitChanged,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: _NumberInput(
                          label: 'Cooldown/người nhận (giờ)',
                          controller: cooldownController,
                          onChanged: onCooldownChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberInput(
                          label: 'Ngưỡng duyệt thủ công',
                          controller: approvalThresholdController,
                          onChanged: onApprovalThresholdChanged,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: _NumberInput(
                          label: 'Tỷ lệ lỗi tối đa (%)',
                          controller: failureRateController,
                          onChanged: onFailureRateChanged,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: _NumberInput(
                          label: 'Dừng khi bị báo cáo (lần)',
                          controller: stopReportController,
                          onChanged: onStopReportChanged,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.m),

          // Quiet hours
          Text(
            'Giờ im lặng (không gửi)',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 400;
              if (stack) {
                return Column(
                  children: [
                    _TextInput(
                      label: 'Bắt đầu',
                      controller: quietStartController,
                      onChanged: onQuietStartChanged,
                      hintText: '21:00',
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _TextInput(
                      label: 'Kết thúc',
                      controller: quietEndController,
                      onChanged: onQuietEndChanged,
                      hintText: '08:00',
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _TextInput(
                      label: 'Bắt đầu',
                      controller: quietStartController,
                      onChanged: onQuietStartChanged,
                      hintText: '21:00',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: _TextInput(
                      label: 'Kết thúc',
                      controller: quietEndController,
                      onChanged: onQuietEndChanged,
                      hintText: '08:00',
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              text: 'Lưu cài đặt rủi ro',
              icon: Icons.save_outlined,
              isLoading: isLoading,
              onPressed: onSave,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: AppTextStyles.bodyMedium),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}

class _DisabledSwitchRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final bool isDisabled;
  final ValueChanged<bool> onChanged;

  const _DisabledSwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.isDisabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: SwitchListTile(
        value: value,
        onChanged: isDisabled ? null : (v) => onChanged(v),
        contentPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
            if (isDisabled)
              const AppBadge(
                label: 'Bị vô hiệu',
                variant: AppBadgeVariant.warning,
              ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _ChannelModeRow extends StatelessWidget {
  final ZaloChannelMode currentMode;
  final ValueChanged<ZaloChannelMode?> onChanged;

  const _ChannelModeRow({
    required this.currentMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kênh Zalo', style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Chọn kênh tích hợp: Personal Zalo (zca-js), Official OA, hoặc Mock.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.s),
          DropdownButtonFormField<ZaloChannelMode>(
            initialValue: currentMode,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: ZaloChannelMode.personalZca,
                child: Text('Personal Zalo (zca-js)'),
              ),
              DropdownMenuItem(
                value: ZaloChannelMode.officialOa,
                child: Text('Official OA'),
              ),
              DropdownMenuItem(
                value: ZaloChannelMode.mock,
                child: Text('Mock / Test'),
              ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _AdvancedCard extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final ValueChanged<bool> onChanged;
  final VoidCallback onSave;

  const _AdvancedCard({
    required this.enabled,
    required this.isLoading,
    required this.onChanged,
    required this.onSave,
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
                Icons.settings_suggest_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const Spacer(),
              Text(
                'Tính năng tự động nâng cao',
                style: AppTextStyles.sectionTitle,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          CheckboxListTile(
            value: enabled,
            onChanged: (value) => onChanged(value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'Tự động đồng ý kết bạn',
              style: AppTextStyles.bodyMedium,
            ),
            subtitle: Text(
              'Tự động chấp nhận lời mời kết bạn từ người lạ trong thời gian thực (realtime & offline check).',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              text: 'Lưu cài đặt',
              icon: Icons.save_outlined,
              isLoading: isLoading,
              onPressed: onSave,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const _NumberInput({
    required this.label,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppTextStyles.body,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TextInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? hintText;

  const _TextInput({
    required this.label,
    required this.controller,
    this.onChanged,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          style: AppTextStyles.body,
          onChanged: onChanged,
          decoration: InputDecoration(hintText: hintText),
        ),
      ],
    );
  }
}
