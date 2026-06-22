import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../mock/mock_campaigns.dart';
import '../../../../mock/mock_groups.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_search_field.dart';
import '../../../../shared/widgets/app_select_field.dart';
import '../../../../shared/widgets/activity_log_panel.dart';
import '../../../../shared/widgets/list_item_tiles.dart';
import '../../providers/leave_groups_provider.dart';
import '../../../zalo_integration/providers/zalo_integration_provider.dart';

class LeaveGroupsScreen extends ConsumerStatefulWidget {
  const LeaveGroupsScreen({super.key});

  @override
  ConsumerState<LeaveGroupsScreen> createState() => _LeaveGroupsScreenState();
}

class _LeaveGroupsScreenState extends ConsumerState<LeaveGroupsScreen> {
  final _searchController = TextEditingController();
  final _minDelayController = TextEditingController(text: '5');
  final _maxDelayController = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(zaloIntegrationProvider.notifier).checkConnection().then((_) {
        ref.read(leaveGroupsProvider.notifier).reloadGroups();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minDelayController.dispose();
    _maxDelayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leaveGroupsProvider);
    final notifier = ref.read(leaveGroupsProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    // Filter groups list by account first, then by search query
    final filteredGroups = state.groups.where((g) {
      // Account filter (same logic as invite tab)
      if (state.selectedAccountId != null) {
        if (g.accountId != null) {
          if (g.accountId != state.selectedAccountId) return false;
        } else if (state.selectedAccountId!.length >= 4) {
          final suffix = state.selectedAccountId!.substring(
            state.selectedAccountId!.length - 4,
          );
          if (!g.name.startsWith('[$suffix]')) return false;
        }
      }
      // Search filter
      final q = state.searchQuery.toLowerCase();
      return q.isEmpty || g.name.toLowerCase().contains(q);
    }).toList();

    final zaloState = ref.watch(zaloIntegrationProvider);
    final activeAccounts = zaloState.accounts;

    if (state.selectedAccountId == null && activeAccounts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.setAccount(activeAccounts.first.id);
      });
    }

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.l),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useColumns = constraints.maxWidth >= 1100;
                  final col1 = _buildConfigCard(
                    state,
                    notifier,
                    activeAccounts,
                    useColumns,
                  );
                  final col2 = _buildGroupsCard(
                    state,
                    notifier,
                    filteredGroups,
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

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.group_off_outlined,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rời nhóm hàng loạt', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Chọn hàng loạt nhóm Zalo không còn hoạt động hoặc không cần thiết để tự động rời nhóm.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigCard(
    LeaveGroupsState state,
    LeaveGroupsNotifier notifier,
    List<ZaloConnectedAccount> accounts,
    bool useColumns,
  ) {
    final hasActiveAccount = accounts.isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('CẤU HÌNH RỜI NHÓM', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Chọn tài khoản nguồn và phương thức rời nhóm',
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
              hintText: 'Chọn tài khoản...',
              items: accounts.map((acc) {
                String cleanLabel = acc.label;
                cleanLabel = cleanLabel.replaceAll(
                  RegExp(r'\s*\([^)]*\)$'),
                  '',
                ); // Remove phone at the end
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
                          cleanLabel.isNotEmpty ? cleanLabel : 'Tài khoản',
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
          SwitchListTile(
            title: Text(
              'Rời nhóm âm thầm',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Rời đi không hiển thị thông báo "Ai đó đã rời nhóm" trong khung chat Zalo',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
            value: state.isSilent,
            onChanged: state.isRunning ? null : notifier.setIsSilent,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
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
                        style: AppTextStyles.body,
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
                        style: AppTextStyles.body,
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
                ? 'Dừng rời nhóm'
                : 'Bắt đầu rời nhóm (${state.selectedGroupIds.length})',
            icon: state.isRunning ? Icons.stop_rounded : Icons.logout_rounded,
            variant: state.isRunning
                ? AppButtonVariant.primary
                : AppButtonVariant.destructive,
            onPressed: !hasActiveAccount || state.selectedGroupIds.isEmpty
                ? null
                : () {
                    if (state.isRunning) {
                      notifier.stopLeaveCampaign();
                    } else {
                      _showConfirmDialog(notifier);
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsCard(
    LeaveGroupsState state,
    LeaveGroupsNotifier notifier,
    List<ZaloGroup> visibleGroups,
  ) {
    final allSelected =
        visibleGroups.isNotEmpty &&
        visibleGroups.every((g) => state.selectedGroupIds.contains(g.id));

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
                    hintText: 'Tìm kiếm nhóm đã tham gia...',
                    onChanged: notifier.setSearchQuery,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                IconButton(
                  icon: state.isLoadingGroups
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.refresh_rounded,
                          color: AppColors.textSecondary,
                        ),
                  onPressed: state.isRunning || state.isLoadingGroups
                      ? null
                      : notifier.reloadGroups,
                  tooltip: 'Tải lại danh sách nhóm',
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderSoft),
          CheckboxListTile(
            title: Text(
              'Chọn tất cả nhóm (${visibleGroups.length})',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            value: allSelected,
            enabled: !state.isRunning && !state.isLoadingGroups,
            onChanged: (val) {
              notifier.toggleAllGroups(visibleGroups);
            },
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
            ),
          ),
          Divider(height: 1, color: AppColors.borderSoft),
          Expanded(
            child: state.isLoadingGroups
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  )
                : visibleGroups.isEmpty
                ? Center(
                    child: Text(
                      'Không tìm thấy nhóm nào.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: visibleGroups.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: AppColors.borderSoft),
                    itemBuilder: (context, index) {
                      final group = visibleGroups[index];
                      return GroupCheckboxTile(
                        key: ValueKey(group.id),
                        group: group,
                        isChecked: state.selectedGroupIds.contains(group.id),
                        enabled: !state.isRunning,
                        onToggle: notifier.toggleGroup,
                        trailing: AppBadge(
                          label: group.role,
                          variant: group.role == 'Trưởng nhóm'
                              ? AppBadgeVariant.error
                              : group.role == 'Phó nhóm'
                              ? AppBadgeVariant.warning
                              : AppBadgeVariant.neutral,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(LeaveGroupsState state, LeaveGroupsNotifier notifier) {
    return ActivityLogPanel(
      logs: state.logs,
      isRunning: state.isRunning,
      onClear: notifier.clearLogs,
      height: double.infinity,
    );
  }

  void _showConfirmDialog(LeaveGroupsNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: 'Xác nhận rời nhóm',
        icon: Icons.warning_amber_rounded,
        actions: [
          AppDialogAction(
            text: 'Hủy bỏ',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(context).pop(),
          ),
          AppDialogAction(
            text: 'Đồng ý rời nhóm',
            variant: AppButtonVariant.destructive,
            onPressed: () {
              Navigator.of(context).pop();
              notifier.startLeaveCampaign();
            },
          ),
        ],
        child: Text(
          'Hành động rời nhóm chat Zalo là không thể hoàn tác. Bạn có chắc chắn muốn rời khỏi các nhóm đã chọn không?',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );
  }
}
