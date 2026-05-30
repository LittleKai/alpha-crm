import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../mock/mock_groups.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_search_field.dart';
import '../../../../shared/widgets/activity_log_panel.dart';
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

  @override
  void initState() {
    super.initState();
    _namesController.addListener(() {
      ref
          .read(createGroupsProvider.notifier)
          .setGroupNames(_namesController.text);
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
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final filteredFriends = state.friends.where((f) {
      final q = state.searchQuery.toLowerCase();
      return q.isEmpty ||
          f.name.toLowerCase().contains(q) ||
          f.phone.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.appBackground,
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
                  final col1 = _buildConfigCard(state, notifier, useColumns);
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
    bool useColumns,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('CẤU HÌNH TẠO NHÓM', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Nhập tên nhóm và cấu hình thời gian delay',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            'Tên các nhóm cần tạo (mỗi dòng một nhóm) *',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: AppSpacing.xs),
          if (useColumns)
            Expanded(
              child: TextField(
                controller: _namesController,
                enabled: !state.isRunning,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: AppTextStyles.body,
                decoration: const InputDecoration(
                  hintText:
                      'VD: Khách hàng Bất Động Sản Q9\nHội Thảo Alpha Studio 2026',
                  alignLabelWithHint: true,
                ),
              ),
            )
          else
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
          if (useColumns) const Spacer() else const SizedBox(height: AppSpacing.xl),
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
                        title: Text(
                          friend.name,
                          style: AppTextStyles.bodyMedium,
                        ),
                        subtitle: Text(
                          friend.phone,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
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
