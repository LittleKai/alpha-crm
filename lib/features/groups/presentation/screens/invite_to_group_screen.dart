import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../mock/mock_groups.dart';
import '../../../../shared/widgets/compliance_warnings_popup.dart';
import '../../../../shared/utils/zalo_compliance_guard.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_search_field.dart';
import '../../../../shared/widgets/app_select_field.dart';
import '../../../../shared/widgets/activity_log_panel.dart';
import '../../providers/invite_to_group_provider.dart';
import '../../../zalo_integration/providers/zalo_integration_provider.dart';

class InviteToGroupScreen extends ConsumerStatefulWidget {
  const InviteToGroupScreen({super.key});

  @override
  ConsumerState<InviteToGroupScreen> createState() =>
      _InviteToGroupScreenState();
}

class _InviteToGroupScreenState extends ConsumerState<InviteToGroupScreen> {
  final _searchController = TextEditingController();
  final _maxInviteController = TextEditingController(text: '50');
  final _minDelayController = TextEditingController(text: '5');
  final _maxDelayController = TextEditingController(text: '10');
  String _phoneFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(zaloIntegrationProvider.notifier).checkConnection();
      ref.read(inviteToGroupProvider.notifier).loadFriends();
      ref.read(inviteToGroupProvider.notifier).loadGroups();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _maxInviteController.dispose();
    _minDelayController.dispose();
    _maxDelayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inviteToGroupProvider);
    final notifier = ref.read(inviteToGroupProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    // Filter friends list
    final filteredFriends = state.friends.where((f) {
      final q = state.searchQuery.toLowerCase();
      final matchesSearch =
          q.isEmpty || f.name.toLowerCase().contains(q) || f.phone.contains(q);

      if (!matchesSearch) return false;

      if (_phoneFilter == 'has_phone') {
        return f.phone.isNotEmpty;
      } else if (_phoneFilter == 'no_phone') {
        return f.phone.isEmpty;
      }
      return true;
    }).toList();

    final zaloState = ref.watch(zaloIntegrationProvider);
    final activeAccounts = zaloState.accounts;

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
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  final col1 = _buildConfigCard(
                    state,
                    notifier,
                    activeAccounts,
                    useColumns,
                    filteredGroups,
                  );
                  final col2 = _buildFriendsCard(
                    state,
                    notifier,
                    filteredFriends,
                  );
                  final col3 = _buildLogCard(state, notifier);

                  if (!useColumns) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          col1,
                          const SizedBox(height: AppSpacing.m),
                          SizedBox(height: 380, child: col2),
                          const SizedBox(height: AppSpacing.m),
                          SizedBox(height: 300, child: col3),
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 4, child: col1),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(flex: 6, child: col2),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(flex: 5, child: col3),
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

  Widget _buildHeader(InviteToGroupState state) {
    final settings = ref.watch(settingsProvider).settings;
    final decision = ZaloComplianceGuard.evaluateZaloAction(
      settings: settings,
      actionType: ZaloActionType.inviteToGroup,
      targetCount: state.selectedFriendIds.length,
    );
    final activeWarning = decision.allowed
        ? (decision.riskLevel != ZaloRiskLevel.low ? '${decision.title}: ${decision.message}' : null)
        : '${decision.title}: ${decision.message}';
    final hasWarningOrError = activeWarning != null;

    return Row(
      children: [
        const Icon(
          Icons.person_add_alt_1_outlined,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mời bạn bè vào nhóm', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Chọn danh sách bạn bè Zalo để mời tự động vào nhóm Zalo do bạn làm Quản trị viên/Phó nhóm.',
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
              actionType: ZaloActionType.inviteToGroup,
            );
          },
        ),
        const SizedBox(width: AppSpacing.s),
      ],
    );
  }

  Widget _buildConfigCard(
    InviteToGroupState state,
    InviteToGroupNotifier notifier,
    List<ZaloConnectedAccount> accounts,
    bool useColumns,
    List<ZaloGroup> filteredGroups,
  ) {
    final hasActiveAccount = accounts.isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('CẤU HÌNH LỜI MỜI', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Thiết lập tài khoản nguồn và nhóm Zalo đích',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.m),
          Text('Chọn tài khoản Zalo *', style: AppTextStyles.label),
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
              hintText: 'Chọn tài khoản gửi...',
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
          Text('Chọn nhóm Zalo nhận lời mời *', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.xs),
          AppSelectField<String>(
            value: filteredGroups.any((g) => g.id == state.selectedGroupId)
                ? state.selectedGroupId
                : null,
            hintText: 'Chọn nhóm nhận...',
            items: filteredGroups
                .map(
                  (g) => DropdownMenuItem(
                    value: g.id,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.surfaceMuted,
                          backgroundImage: g.avatarUrl.isNotEmpty
                              ? NetworkImage(g.avatarUrl)
                              : null,
                          child: g.avatarUrl.isEmpty
                              ? Text(
                                  g.name.isNotEmpty
                                      ? g.name[0].toUpperCase()
                                      : 'G',
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
                            '${g.name} (${g.memberCount} TV)',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: state.isRunning ? null : notifier.setGroupId,
          ),
          const SizedBox(height: AppSpacing.m),
          Text('Số lượng mời tối đa', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 40,
            child: TextField(
              controller: _maxInviteController,
              enabled: !state.isRunning,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.body,
              onChanged: (val) =>
                  notifier.setMaxInvite(int.tryParse(val) ?? 50),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.m),
              ),
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
          if (useColumns)
            const Spacer()
          else
            const SizedBox(height: AppSpacing.xl),
          AppButton(
            text: state.isRunning
                ? 'Dừng mời bạn bè'
                : 'Bắt đầu mời (${state.selectedFriendIds.length})',
            icon: state.isRunning
                ? Icons.stop_rounded
                : Icons.play_arrow_rounded,
            variant: state.isRunning
                ? AppButtonVariant.destructive
                : AppButtonVariant.primary,
            onPressed:
                !hasActiveAccount ||
                    state.selectedGroupId == null ||
                    state.selectedFriendIds.isEmpty
                ? null
                : () {
                    if (state.isRunning) {
                      notifier.stopInviteCampaign();
                    } else {
                      notifier.startInviteCampaign();
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsCard(
    InviteToGroupState state,
    InviteToGroupNotifier notifier,
    List<FriendRecord> visibleFriends,
  ) {
    final allSelected =
        visibleFriends.isNotEmpty &&
        visibleFriends.every((f) => state.selectedFriendIds.contains(f.id));

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    controller: _searchController,
                    hintText: 'Tìm bạn bè theo tên/SĐT...',
                    onChanged: notifier.setSearchQuery,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                SizedBox(
                  width: 140,
                  height: 40,
                  child: DropdownButtonFormField<String>(
                    value: _phoneFilter,
                    style: AppTextStyles.bodyMedium,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.s,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('Tất cả bạn bè'),
                      ),
                      DropdownMenuItem(
                        value: 'has_phone',
                        child: Text('Có SĐT'),
                      ),
                      DropdownMenuItem(
                        value: 'no_phone',
                        child: Text('Không SĐT'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _phoneFilter = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          CheckboxListTile(
            title: Text(
              'Chọn tất cả bạn bè (${visibleFriends.length})',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            value: allSelected,
            enabled: !state.isRunning,
            onChanged: (val) {
              notifier.toggleAllFriends(visibleFriends);
            },
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          Expanded(
            child: visibleFriends.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy bạn bè nào.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: visibleFriends.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: AppColors.borderSoft),
                    itemBuilder: (context, index) {
                      final friend = visibleFriends[index];
                      final isChecked = state.selectedFriendIds.contains(
                        friend.id,
                      );
                      return CheckboxListTile(
                        title: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.surfaceMuted,
                              backgroundImage: friend.avatarUrl.isNotEmpty
                                  ? NetworkImage(friend.avatarUrl)
                                  : null,
                              child: friend.avatarUrl.isEmpty
                                  ? Text(
                                      friend.name.isNotEmpty
                                          ? friend.name
                                                .substring(0, 1)
                                                .toUpperCase()
                                          : 'F',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.s),
                            Expanded(
                              child: Text(
                                friend.name,
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        subtitle: friend.phone.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(left: 36.0),
                                child: Text(
                                  friend.phone,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              )
                            : null,
                        value: isChecked,
                        enabled: !state.isRunning,
                        onChanged: (val) => notifier.toggleFriend(friend.id),
                        activeColor: AppColors.primary,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.m,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(
    InviteToGroupState state,
    InviteToGroupNotifier notifier,
  ) {
    return ActivityLogPanel(
      logs: state.logs,
      isRunning: state.isRunning,
      onClear: notifier.clearLogs,
      height: double.infinity,
    );
  }
}
