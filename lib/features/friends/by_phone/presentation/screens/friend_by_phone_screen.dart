import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/widgets/compliance_warnings_popup.dart';
import '../../../../../shared/utils/zalo_compliance_guard.dart';
import '../../../../settings/providers/settings_provider.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_alert.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/app_select_field.dart';
import '../../../../../shared/widgets/activity_log_panel.dart';
import '../../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../providers/friend_by_phone_provider.dart';

class FriendByPhoneScreen extends ConsumerStatefulWidget {
  const FriendByPhoneScreen({super.key});

  @override
  ConsumerState<FriendByPhoneScreen> createState() =>
      _FriendByPhoneScreenState();
}

class _FriendByPhoneScreenState extends ConsumerState<FriendByPhoneScreen> {
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  final _minDelayController = TextEditingController(text: '30');
  final _maxDelayController = TextEditingController(text: '60');

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(friendByPhoneProvider.notifier);

    // Wire controllers to provider
    _phoneController.addListener(() {
      notifier.setPhones(_phoneController.text);
    });
    _messageController.addListener(() {
      notifier.setMessage(_messageController.text);
    });

    // Load initial values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(zaloIntegrationProvider.notifier).checkConnection();
      final state = ref.read(friendByPhoneProvider);
      _messageController.text = state.messageText;
      _minDelayController.text = state.minDelay.toString();
      _maxDelayController.text = state.maxDelay.toString();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    _minDelayController.dispose();
    _maxDelayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendByPhoneProvider);
    final notifier = ref.read(friendByPhoneProvider.notifier);
    final zaloState = ref.watch(zaloIntegrationProvider);
    final activeAccounts = zaloState.accounts;
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    // Auto-select first account if not set
    if (state.selectedAccountId == null && activeAccounts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.setAccount(activeAccounts.first.id);
      });
    }

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(state),
            if (state.complianceError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppAlert(
                title: 'Hành động bị chặn',
                message: state.complianceError!,
                variant: AppAlertVariant.error,
              ),
            ],
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useColumns = constraints.maxWidth >= 1024;
                  final leftCard = _buildConfigCard(
                    state,
                    notifier,
                    activeAccounts,
                  );
                  final rightCard = _buildLogCard(state, notifier);

                  if (!useColumns) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          leftCard,
                          const SizedBox(height: AppSpacing.m),
                          SizedBox(height: 380, child: rightCard),
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: leftCard),
                      const SizedBox(width: AppSpacing.m),
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

  Widget _buildHeader(FriendByPhoneState state) {
    final settings = ref.watch(settingsProvider).settings;
    final phonesCount = state.phoneListText
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .length;
    final decision = ZaloComplianceGuard.evaluateZaloAction(
      settings: settings,
      actionType: ZaloActionType.friendByPhone,
      targetCount: phonesCount > 0 ? phonesCount : 1,
    );
    final activeWarning = decision.allowed
        ? (decision.riskLevel != ZaloRiskLevel.low
              ? '${decision.title}: ${decision.message}'
              : null)
        : '${decision.title}: ${decision.message}';
    final hasWarningOrError = activeWarning != null;

    return Row(
      children: [
        const Icon(
          Icons.phone_in_talk_outlined,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kết bạn theo Số điện thoại',
                style: AppTextStyles.pageTitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tự động tìm kiếm và gửi lời mời kết bạn an toàn theo danh sách SĐT.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            hasWarningOrError
                ? Icons.warning_amber_rounded
                : Icons.gpp_good_outlined,
            color: hasWarningOrError ? AppColors.warning : AppColors.textMuted,
            size: 28,
          ),
          tooltip: hasWarningOrError
              ? 'Có khuyến cáo an toàn (Nhấn để xem)'
              : 'Hệ thống an toàn (Nhấn để xem)',
          onPressed: () {
            showComplianceWarningsDialog(
              context,
              activeWarning: activeWarning,
              actionType: ZaloActionType.friendByPhone,
            );
          },
        ),
        const SizedBox(width: AppSpacing.s),
      ],
    );
  }

  Widget _buildConfigCard(
    FriendByPhoneState state,
    FriendByPhoneNotifier notifier,
    List<ZaloConnectedAccount> accounts,
  ) {
    final hasActiveAccount = accounts.isNotEmpty;

    return AppCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'CẤU HÌNH CHIẾN DỊCH KẾT BẠN',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Chọn tài khoản nguồn, dán SĐT và chỉnh giãn cách an toàn',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.m),
            Text('Chọn tài khoản gửi yêu cầu *', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.xs),
            if (!hasActiveAccount) ...[
              const AppAlert(
                message:
                    'Chưa có tài khoản kết nối. Vui lòng vào Cài đặt để kết nối.',
                variant: AppAlertVariant.error,
              ),
              const SizedBox(height: AppSpacing.m),
            ] else ...[
              AppSelectField<String>(
                value: accounts.any((acc) => acc.id == state.selectedAccountId)
                    ? state.selectedAccountId
                    : null,
                hintText: 'Chọn tài khoản Zalo...',
                items: accounts.map((acc) {
                  String cleanLabel = acc.label;
                  cleanLabel = cleanLabel.replaceAll(
                    RegExp(r'\s*\([^)]*\)$'),
                    '',
                  ); // Remove phone
                  cleanLabel = cleanLabel.replaceAll(
                    RegExp(r'^\[\d+\]\s*'),
                    '',
                  ); // Remove ID prefix

                  return DropdownMenuItem(
                    value: acc.id,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.surfaceMuted,
                          backgroundImage: acc.avatarUrl.isNotEmpty
                              ? NetworkImage(acc.avatarUrl)
                              : null,
                          child: acc.avatarUrl.isEmpty
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                )
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: Text(
                            cleanLabel,
                            style: AppTextStyles.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: state.isRunning ? null : notifier.setAccount,
              ),
              const SizedBox(height: AppSpacing.m),
            ],
            Text(
              'Danh sách số điện thoại (mỗi dòng một số) *',
              style: AppTextStyles.label,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _phoneController,
              enabled: !state.isRunning,
              minLines: 5,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              style: AppTextStyles.body,
              decoration: const InputDecoration(
                hintText: '0901112222\n0983334444',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text('Lời nhắn kết bạn *', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _messageController,
              enabled: !state.isRunning,
              maxLines: 3,
              style: AppTextStyles.body,
              decoration: const InputDecoration(
                hintText: 'Chào bạn, mình kết bạn nhé!',
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Delay tối thiểu (s)', style: AppTextStyles.label),
                      const SizedBox(height: AppSpacing.xs),
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _minDelayController,
                          enabled: !state.isRunning,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: AppTextStyles.body,
                          onChanged: (val) =>
                              notifier.setMinDelay(int.tryParse(val) ?? 30),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.m,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Delay tối đa (s)', style: AppTextStyles.label),
                      const SizedBox(height: AppSpacing.xs),
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _maxDelayController,
                          enabled: !state.isRunning,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: AppTextStyles.body,
                          onChanged: (val) =>
                              notifier.setMaxDelay(int.tryParse(val) ?? 60),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.m,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'Tải SĐT mẫu',
                    variant: AppButtonVariant.outline,
                    icon: Icons.download_rounded,
                    onPressed: state.isRunning
                        ? null
                        : () {
                            _phoneController.text =
                                '0901112222\n0903334444\n0905556666';
                          },
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: AppButton(
                    text: state.isRunning ? 'Dừng chạy' : 'Bắt đầu chạy',
                    icon: state.isRunning
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                    variant: state.isRunning
                        ? AppButtonVariant.destructive
                        : AppButtonVariant.primary,
                    onPressed:
                        !hasActiveAccount ||
                            (state.phoneListText.trim().isEmpty &&
                                !state.isRunning)
                        ? null
                        : () {
                            if (state.isRunning) {
                              notifier.stopCampaign();
                            } else {
                              notifier.startCampaign();
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(
    FriendByPhoneState state,
    FriendByPhoneNotifier notifier,
  ) {
    return ActivityLogPanel(
      logs: state.logs,
      isRunning: state.isRunning,
      onClear: notifier.clearLogs,
      height: double.infinity,
    );
  }
}
