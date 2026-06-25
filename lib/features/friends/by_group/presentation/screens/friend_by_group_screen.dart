import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_alert.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/app_select_field.dart';
import '../../../../../shared/widgets/list_item_tiles.dart';
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
    return Row(
      children: [
        Icon(Icons.groups_2_outlined, color: AppColors.primary, size: 32),
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
        const SizedBox(width: AppSpacing.s),
        IconButton(
          tooltip: 'Làm mới dữ liệu',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.read(zaloIntegrationProvider.notifier).checkConnection();
            ref.read(friendByGroupProvider.notifier).loadGroups();
          },
        ),
      ],
    );
  }

  Widget _buildMemberPanel(
    FriendByGroupState state,
    FriendByGroupNotifier notifier,
    List<ZaloGroup> filteredGroups,
  ) {
    bool isSelf(String id) {
      if (state.selectedAccountId == null || state.selectedAccountId!.isEmpty) return false;
      return id == state.selectedAccountId;
    }
    
    final selectableMembers = state.members.where((m) => !isSelf(m.id) && m.status != 'Đã kết bạn').toList();

    final allSelected =
        selectableMembers.isNotEmpty &&
        selectableMembers.every((m) => state.selectedMemberIds.contains(m.id));

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
                if (_sourceTab == 0) ...[
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
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Divider(color: AppColors.borderSoft),
                  const SizedBox(height: AppSpacing.s),
                  if (state.savedGroups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                      child: Text(
                        'Chưa có nhóm nào được quét hoặc lưu.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Icon(Icons.history, size: 16, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Nhóm đã quét gần đây (${state.savedGroups.length}):',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s),
                    SizedBox(
                      height: 105,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: state.savedGroups.length,
                        itemBuilder: (context, index) {
                          final group = state.savedGroups[index];
                          final isSelected = state.selectedGroupId == group.id;

                          return Container(
                            width: 220,
                            margin: const EdgeInsets.only(right: AppSpacing.sm),
                            child: Stack(
                              children: [
                                Material(
                                  color: isSelected
                                      ? AppColors.primarySoft
                                      : AppColors.surface,
                                  borderRadius: AppSpacing.borderRadiusM,
                                  child: InkWell(
                                    onTap: () {
                                      if (isSelected) {
                                        notifier.selectSavedGroup(null);
                                        _linkController.clear();
                                      } else {
                                        notifier.selectSavedGroup(group.id);
                                        _linkController.text =
                                            'https://zalo.me/g/${group.id}';
                                      }
                                    },
                                    borderRadius: AppSpacing.borderRadiusM,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        borderRadius: AppSpacing.borderRadiusM,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.borderSoft,
                                          width: isSelected ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: AppColors.surfaceMuted,
                                            backgroundImage: group.avatarUrl.isNotEmpty
                                                ? NetworkImage(group.avatarUrl)
                                                : null,
                                            child: group.avatarUrl.isEmpty
                                                ? Text(
                                                    group.name.isNotEmpty
                                                        ? group.name
                                                              .substring(0, 1)
                                                              .toUpperCase()
                                                        : 'G',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: AppSpacing.s),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  group.name,
                                                  style: AppTextStyles.bodyMedium
                                                      .copyWith(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12.5,
                                                      ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${group.memberCount} thành viên',
                                                  style: AppTextStyles.caption.copyWith(
                                                    color: AppColors.textMuted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: InkWell(
                                    onTap: () {
                                      notifier.removeSavedGroup(group.id);
                                      if (state.selectedGroupId == group.id) {
                                        _linkController.clear();
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceMuted,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.borderSoft),
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ]
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
                            ...filteredGroups.map((group) {
                              final cleanGroupName = group.name.replaceAll(
                                RegExp(r'^\[\d+\]\s*'),
                                '',
                              );
                              return DropdownMenuItem(
                                value: group.id,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppColors.surfaceMuted,
                                      backgroundImage:
                                          group.avatarUrl.isNotEmpty
                                          ? NetworkImage(group.avatarUrl)
                                          : null,
                                        child: group.avatarUrl.isEmpty
                                            ? Icon(
                                                Icons.groups_rounded,
                                                size: 14,
                                                color: AppColors.textSecondary,
                                              )
                                            : null,
                                    ),
                                    const SizedBox(width: AppSpacing.s),
                                    Expanded(
                                      child: Text(
                                        '$cleanGroupName (${group.memberCount} TV)',
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
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
          Divider(height: 1, color: AppColors.borderSoft),
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
              onChanged: (val) {
                if (val == true) {
                  // select all except self
                  for (final m in selectableMembers) {
                    if (!state.selectedMemberIds.contains(m.id)) {
                      notifier.toggleMember(m.id);
                    }
                  }
                } else {
                  // deselect all
                  for (final m in selectableMembers) {
                    if (state.selectedMemberIds.contains(m.id)) {
                      notifier.toggleMember(m.id);
                    }
                  }
                }
              },
              activeColor: AppColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
              ),
            ),
            Divider(height: 1, color: AppColors.borderSoft),
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
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: state.members.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: AppColors.borderSoft),
                    itemBuilder: (context, index) {
                      final member = state.members[index];
                      final self = isSelf(member.id);
                      final isChecked = self ? false : state.selectedMemberIds.contains(member.id);

                      return ScannedMemberCheckboxTile(
                        key: ValueKey(member.id),
                        member: member,
                        isChecked: isChecked,
                        enabled: !state.isRunning,
                        isSelf: self,
                        onToggle: self ? (id) {} : notifier.toggleMember,
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
                Icon(Icons.settings_outlined, color: AppColors.primary),
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
            Divider(color: AppColors.borderSoft),
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
