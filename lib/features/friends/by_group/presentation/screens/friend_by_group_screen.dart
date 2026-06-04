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
import '../../../../../shared/widgets/app_tabs.dart';
import '../../../../../shared/widgets/activity_log_panel.dart';
import '../../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../../../../mock/mock_groups.dart';
import '../../providers/friend_by_group_provider.dart';

class FriendByGroupScreen extends ConsumerStatefulWidget {
  const FriendByGroupScreen({super.key});

  @override
  ConsumerState<FriendByGroupScreen> createState() =>
      _FriendByGroupScreenState();
}

class _FriendByGroupScreenState extends ConsumerState<FriendByGroupScreen> {
  final _linkController = TextEditingController();
  final _messageController = TextEditingController();
  final _minDelayController = TextEditingController(text: '30');
  final _maxDelayController = TextEditingController(text: '60');
  int _sourceTab = 0;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(friendByGroupProvider.notifier);

    _messageController.addListener(() {
      notifier.setMessage(_messageController.text);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(zaloIntegrationProvider.notifier).checkConnection();
      notifier.loadGroups();

      final state = ref.read(friendByGroupProvider);
      _messageController.text = state.messageText;
      _minDelayController.text = state.minDelay.toString();
      _maxDelayController.text = state.maxDelay.toString();
    });
  }

  @override
  void dispose() {
    _linkController.dispose();
    _messageController.dispose();
    _minDelayController.dispose();
    _maxDelayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendByGroupProvider);
    final notifier = ref.read(friendByGroupProvider.notifier);
    final zaloState = ref.watch(zaloIntegrationProvider);
    final activeAccounts = zaloState.accounts;
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    if (state.selectedAccountId == null && activeAccounts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.setAccount(activeAccounts.first.id);
      });
    }

    final filteredGroups = state.groups.where((g) {
      if (state.selectedAccountId == null) return true;
      if (g.accountId != null) {
        return g.accountId == state.selectedAccountId;
      }
      if (state.selectedAccountId!.length < 4) return true;
      final suffix = state.selectedAccountId!.substring(
        state.selectedAccountId!.length - 4,
      );
      return g.name.startsWith('[$suffix]');
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.appBackground,
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
                  final useColumns = constraints.maxWidth >= 1100;
                  final memberPanel = _buildMemberPanel(
                    state,
                    notifier,
                    filteredGroups,
                  );
                  final configPanel = _buildConfigCard(
                    state,
                    notifier,
                    activeAccounts,
                  );

                  if (!useColumns) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 560, child: memberPanel),
                          const SizedBox(height: AppSpacing.m),
                          configPanel,
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: memberPanel),
                      const SizedBox(width: AppSpacing.l),
                      Expanded(flex: 5, child: configPanel),
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

  Widget _buildHeader(FriendByGroupState state) {
    final settings = ref.watch(settingsProvider).settings;
    final decision = ZaloComplianceGuard.evaluateZaloAction(
      settings: settings,
      actionType: ZaloActionType.friendByGroup,
      targetCount: state.selectedMemberIds.length,
    );
    final activeWarning = decision.allowed
        ? (decision.riskLevel != ZaloRiskLevel.low ? '${decision.title}: ${decision.message}' : null)
        : '${decision.title}: ${decision.message}';
    final hasWarningOrError = activeWarning != null;

    return Row(
      children: [
        const Icon(Icons.groups_2_outlined, color: AppColors.primary, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kết bạn từ Nhóm Zalo', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Quét thành viên nhóm và gửi lời mời kết bạn hàng loạt đi kèm giãn cách an toàn.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            hasWarningOrError ? Icons.warning_amber_rounded : Icons.gpp_good_outlined,
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
              actionType: ZaloActionType.friendByGroup,
            );
          },
        ),
        const SizedBox(width: AppSpacing.s),
      ],
    );
  }

  Widget _buildMemberPanel(
    FriendByGroupState state,
    FriendByGroupNotifier notifier,
    List<ZaloGroup> filteredGroups,
  ) {
    final allSelected =
        state.members.isNotEmpty &&
        state.members.every((m) => state.selectedMemberIds.contains(m.id));

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppTabs(
                    isSegmented: true,
                    selectedIndex: _sourceTab,
                    onTabSelected: (index) {
                      setState(() {
                        _sourceTab = index;
                      });
                      notifier.selectSavedGroup(null);
                      _linkController.clear();
                    },
                    tabs: const [
                      AppTabItem(label: 'Quét từ link nhóm'),
                      AppTabItem(label: 'Chọn từ nhóm Zalo'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                if (_sourceTab == 0)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _linkController,
                          style: AppTextStyles.body,
                          decoration: const InputDecoration(
                            hintText: 'Dán link nhóm Zalo (zalo.me/g/...)',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      AppButton(
                        text: 'Quét nhóm',
                        icon: Icons.search,
                        isLoading: state.isScanning,
                        onPressed: () =>
                            notifier.scanGroupLink(_linkController.text),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Text(
                        'Chọn nhóm đã quét:',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: AppSelectField<String>(
                          value:
                              filteredGroups.any(
                                (g) => g.id == state.selectedGroupId,
                              )
                              ? state.selectedGroupId
                              : 'none',
                          items: [
                            const DropdownMenuItem(
                              value: 'none',
                              child: Text('-- Chọn nhóm của bạn --'),
                            ),
                            ...filteredGroups.map(
                              (group) => DropdownMenuItem(
                                value: group.id,
                                child: Text(
                                  '${group.name} (${group.memberCount} thành viên)',
                                ),
                              ),
                            ),
                          ],
                          onChanged: state.isRunning
                              ? null
                              : notifier.selectSavedGroup,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          if (state.members.isNotEmpty) ...[
            CheckboxListTile(
              title: Text(
                'Chọn tất cả thành viên (${state.members.length})',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              value: allSelected,
              enabled: !state.isRunning,
              onChanged: (val) => notifier.toggleAllMembers(state.members),
              activeColor: AppColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSoft),
          ],
          Expanded(
            child: state.isScanning
                ? const Center(child: CircularProgressIndicator())
                : state.members.isEmpty
                ? Center(
                    child: Text(
                      _sourceTab == 0
                          ? 'Vui lòng nhập link nhóm và nhấn "Quét nhóm".'
                          : 'Vui lòng chọn nhóm Zalo để hiện thành viên.',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: state.members.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: AppColors.borderSoft),
                    itemBuilder: (context, index) {
                      final member = state.members[index];
                      final isChecked = state.selectedMemberIds.contains(
                        member.id,
                      );
                      final isOwner = member.role == 'Trưởng nhóm';
                      final isAdmin = member.role == 'Phó nhóm';

                      return CheckboxListTile(
                        value: isChecked,
                        enabled: !state.isRunning,
                        onChanged: (val) => notifier.toggleMember(member.id),
                        activeColor: AppColors.primary,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.m,
                        ),
                        title: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.surfaceMuted,
                              backgroundImage: member.avatarUrl.isNotEmpty
                                  ? NetworkImage(member.avatarUrl)
                                  : null,
                              child: member.avatarUrl.isEmpty
                                  ? Text(
                                      member.name.isNotEmpty
                                          ? member.name[0].toUpperCase()
                                          : 'M',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.s),
                            Expanded(
                              child: Text(
                                member.name,
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                            if (isOwner || isAdmin)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isOwner
                                      ? AppColors.warningSoft
                                      : AppColors.primarySoft,
                                  borderRadius: AppSpacing.borderRadiusS,
                                ),
                                child: Text(
                                  member.role,
                                  style: AppTextStyles.caption.copyWith(
                                    color: isOwner
                                        ? AppColors.warning
                                        : AppColors.primary,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(left: 36.0),
                          child: Text(
                            member.id,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard(
    FriendByGroupState state,
    FriendByGroupNotifier notifier,
    List<ZaloConnectedAccount> accounts,
  ) {
    final hasActiveAccount = accounts.isNotEmpty;

    return AppCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.settings_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.s),
                Text('Cấu hình gửi kết bạn', style: AppTextStyles.sectionTitle),
              ],
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
            const SizedBox(height: AppSpacing.m),
            AppButton(
              text: state.isRunning
                  ? 'Dừng chạy'
                  : 'Bắt đầu chạy (${state.selectedMemberIds.length})',
              icon: state.isRunning
                  ? Icons.stop_rounded
                  : Icons.play_arrow_rounded,
              variant: state.isRunning
                  ? AppButtonVariant.destructive
                  : AppButtonVariant.primary,
              onPressed:
                  !hasActiveAccount ||
                      (state.selectedMemberIds.isEmpty && !state.isRunning)
                  ? null
                  : () {
                      if (state.isRunning) {
                        notifier.stopCampaign();
                      } else {
                        notifier.startCampaign();
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.m),
            const Divider(color: AppColors.borderSoft),
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              height: 200,
              child: ActivityLogPanel(
                logs: state.logs,
                isRunning: state.isRunning,
                onClear: notifier.clearLogs,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
