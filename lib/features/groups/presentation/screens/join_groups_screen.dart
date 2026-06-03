import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_select_field.dart';
import '../../../../shared/widgets/activity_log_panel.dart';
import '../../providers/join_groups_provider.dart';
import '../../../zalo_integration/providers/zalo_integration_provider.dart';

class JoinGroupsScreen extends ConsumerStatefulWidget {
  const JoinGroupsScreen({super.key});

  @override
  ConsumerState<JoinGroupsScreen> createState() => _JoinGroupsScreenState();
}

class _JoinGroupsScreenState extends ConsumerState<JoinGroupsScreen> {
  final _linksController = TextEditingController();
  final _minDelayController = TextEditingController(text: '10');
  final _maxDelayController = TextEditingController(text: '20');

  @override
  void initState() {
    super.initState();
    _linksController.addListener(() {
      ref.read(joinGroupsProvider.notifier).setLinks(_linksController.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(zaloIntegrationProvider.notifier).checkConnection();
    });
  }

  @override
  void dispose() {
    _linksController.dispose();
    _minDelayController.dispose();
    _maxDelayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(joinGroupsProvider);
    final notifier = ref.read(joinGroupsProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final zaloState = ref.watch(zaloIntegrationProvider);
    final activeAccounts = zaloState.accounts;

    if (state.selectedAccountId == null && activeAccounts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.setAccount(activeAccounts.first.id);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
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
                    useColumns,
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

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.group_add_outlined,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tham gia nhóm tự động', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Nhập danh sách link nhóm Zalo để tự động gửi yêu cầu tham gia theo cấu hình giãn cách.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigCard(
    JoinGroupsState state,
    JoinGroupsNotifier notifier,
    List<ZaloConnectedAccount> accounts,
    bool useColumns,
  ) {
    final hasActiveAccount = accounts.isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CẤU HÌNH CHIẾN DỊCH THAM GIA NHÓM',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Chọn tài khoản gửi yêu cầu và nhập link nhóm cần tham gia',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.m),
          Text('Chọn tài khoản gửi yêu cầu *', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.xs),
          if (!hasActiveAccount) ...[
            const AppAlert(
              message:
                  'Chưa có tài khoản kết nối. Vui lòng vào Cài đặt để kết nối ít nhất 1 tài khoản.',
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
                final cleanLabel = acc.label.replaceAll(
                  RegExp(r'\s*\([^)]*\)$'),
                  '',
                );
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
                            ? Text(
                                cleanLabel.isNotEmpty
                                    ? cleanLabel[0].toUpperCase()
                                    : 'A',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Text(cleanLabel, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                );
              }).toList(),
              onChanged: state.isRunning ? null : notifier.setAccount,
            ),
            const SizedBox(height: AppSpacing.m),
          ],
          Text(
            'Danh sách link nhóm Zalo (mỗi dòng một link) *',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _linksController,
            enabled: !state.isRunning,
            minLines: 5,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            style: AppTextStyles.body,
            decoration: const InputDecoration(
              hintText: 'https://zalo.me/g/xxxxx\nhttps://zalo.me/g/yyyyy',
              alignLabelWithHint: true,
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
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Tải links mẫu',
                  variant: AppButtonVariant.outline,
                  icon: Icons.download_rounded,
                  onPressed: state.isRunning
                      ? null
                      : () {
                          _linksController.text =
                              'https://zalo.me/g/fluttervietnam\nhttps://zalo.me/g/startupvietnam\nhttps://zalo.me/g/alphacrmdemo';
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
                          (state.groupLinks.trim().isEmpty && !state.isRunning)
                      ? null
                      : () {
                          if (state.isRunning) {
                            notifier.stopJoinCampaign();
                          } else {
                            notifier.startJoinCampaign();
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(JoinGroupsState state, JoinGroupsNotifier notifier) {
    return ActivityLogPanel(
      logs: state.logs,
      isRunning: state.isRunning,
      onClear: notifier.clearLogs,
      height: double.infinity,
    );
  }
}
