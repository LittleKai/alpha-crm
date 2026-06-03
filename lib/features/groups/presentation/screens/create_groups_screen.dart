import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../mock/mock_groups.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_search_field.dart';
import '../../../../shared/widgets/app_select_field.dart';
import '../../../../shared/widgets/activity_log_panel.dart';
import '../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../providers/create_groups_provider.dart';

class CreateGroupsScreen extends ConsumerStatefulWidget {
  const CreateGroupsScreen({super.key});

  @override
  ConsumerState<CreateGroupsScreen> createState() => _CreateGroupsScreenState();
}

class _CreateGroupsScreenState extends ConsumerState<CreateGroupsScreen> {
  final _namesController = TextEditingController();
  final _searchController = TextEditingController();
  final _minDelayController = TextEditingController(text: '5');
  final _maxDelayController = TextEditingController(text: '10');
  String _phoneFilter = 'all';

  @override
  void initState() {
    super.initState();
    _namesController.addListener(() {
      ref
          .read(createGroupsProvider.notifier)
          .setGroupNames(_namesController.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(zaloIntegrationProvider.notifier).checkConnection();
      ref.read(createGroupsProvider.notifier).loadFriends();
    });
  }

  @override
  void dispose() {
    _namesController.dispose();
    _searchController.dispose();
    _minDelayController.dispose();
    _maxDelayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createGroupsProvider);
    final notifier = ref.read(createGroupsProvider.notifier);
    final zaloState = ref.watch(zaloIntegrationProvider);
    final activeAccounts = zaloState.accounts;
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    if (state.selectedAccountId == null && activeAccounts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.setAccount(activeAccounts.first.id);
      });
    }

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
                  final useColumns = constraints.maxWidth >= 1100;
                  final col1 = _buildConfigCard(
                    state,
                    notifier,
                    activeAccounts,
                    useColumns,
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

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.group_add_rounded, color: AppColors.primary, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tạo nhóm tự động', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Nhập danh sách tên nhóm để tự động tạo nhóm Zalo hàng loạt và tự động thêm các thành viên đã chọn.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigCard(
    CreateGroupsState state,
    CreateGroupsNotifier notifier,
    List<ZaloConnectedAccount> accounts,
    bool useColumns,
  ) {
    final hasActiveAccount = accounts.isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('CẤU HÌNH TẠO NHÓM', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Chọn tài khoản nguồn và nhập tên nhóm cần tạo',
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
            'Tên các nhóm cần tạo (mỗi dòng một nhóm) *',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _namesController,
            enabled: !state.isRunning,
            minLines: 5,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            style: AppTextStyles.body,
            decoration: const InputDecoration(
              hintText:
                  'VD: Khách hàng Bất Động Sản Q9\nHội Thảo Alpha Studio 2026',
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
          AppButton(
            text: state.isRunning
                ? 'Dừng tạo nhóm'
                : 'Tạo nhóm tự động (${state.selectedFriendIds.length})',
            icon: state.isRunning ? Icons.stop_rounded : Icons.add_box_outlined,
            variant: state.isRunning
                ? AppButtonVariant.destructive
                : AppButtonVariant.primary,
            onPressed:
                state.groupNamesText.trim().isEmpty ||
                    state.selectedFriendIds.isEmpty
                ? null
                : () {
                    if (state.isRunning) {
                      notifier.stopCreateCampaign();
                    } else {
                      notifier.startCreateCampaign();
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsCard(
    CreateGroupsState state,
    CreateGroupsNotifier notifier,
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
                    hintText: 'Tìm kiếm bạn bè thêm vào nhóm...',
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

  Widget _buildLogCard(CreateGroupsState state, CreateGroupsNotifier notifier) {
    return ActivityLogPanel(
      logs: state.logs,
      isRunning: state.isRunning,
      onClear: notifier.clearLogs,
      height: double.infinity,
    );
  }
}
