import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/zalo_text_formatter.dart';
import '../../../../../shared/widgets/compliance_warnings_popup.dart';
import '../../../../../shared/widgets/activity_log_panel.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_alert.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/app_search_field.dart';
import '../../../../../shared/widgets/app_select_field.dart';
import '../../../../../shared/widgets/app_tabs.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../providers/bulk_messaging_provider.dart';
import '../../../../groups/manage/providers/managed_groups_provider.dart';
import '../../../../groups/providers/invite_to_group_provider.dart';
import '../../../../groups/providers/scan_members_provider.dart';
import '../../../../customers/providers/customers_provider.dart';
import '../../../../zalo_integration/providers/zalo_integration_provider.dart';

class BulkMessagingScreen extends ConsumerStatefulWidget {
  const BulkMessagingScreen({super.key});

  @override
  ConsumerState<BulkMessagingScreen> createState() =>
      _BulkMessagingScreenState();
}

class _BulkMessagingScreenState extends ConsumerState<BulkMessagingScreen> {
  final _campaignNameController = TextEditingController();
  final _recipientsController = TextEditingController();
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _minDelayController = TextEditingController(text: '30');
  final _maxDelayController = TextEditingController(text: '60');

  @override
  void initState() {
    super.initState();
    _campaignNameController.addListener(() {
      ref
          .read(bulkMessagingProvider.notifier)
          .setCampaignName(_campaignNameController.text);
    });
    _recipientsController.addListener(() {
      ref
          .read(bulkMessagingProvider.notifier)
          .setRecipientsText(_recipientsController.text);
    });
    _messageController.addListener(() {
      ref
          .read(bulkMessagingProvider.notifier)
          .setMessageText(_messageController.text);
    });
  }

  @override
  void dispose() {
    _campaignNameController.dispose();
    _recipientsController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _minDelayController.dispose();
    _maxDelayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bulkMessagingProvider);
    final notifier = ref.read(bulkMessagingProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            const SizedBox(height: AppSpacing.xl),
            _CampaignTabs(
              selectedIndex: state.selectedTab,
              onChanged: notifier.setSelectedTab,
              onManageCampaigns: _showPlaceholder,
            ),
            if (state.complianceError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppAlert(
                title: 'Hành động bị chặn bởi Kiểm soát rủi ro',
                message: state.complianceError!,
                variant: AppAlertVariant.error,
              ),
            ],
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useColumns = constraints.maxWidth >= 1100;
                  final children = [
                    _TargetPanel(
                      selectedTab: state.selectedTab,
                      searchController: _searchController,
                      recipientsController: _recipientsController,
                      isSending: state.isSending,
                      onImport: _importDemoRecipients,
                      onPlaceholder: _showPlaceholder,
                    ),
                    _ConfigPanel(
                      state: state,
                      onSelectTemplate: _showTemplateDialog,
                      campaignNameController: _campaignNameController,
                      messageController: _messageController,
                      minDelayController: _minDelayController,
                      maxDelayController: _maxDelayController,
                      notifier: notifier,
                      onPlaceholder: _showPlaceholder,
                    ),
                    _ZaloPreview(message: state.messageText),
                  ];

                  if (!useColumns) {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          children[0],
                          const SizedBox(height: AppSpacing.m),
                          children[1],
                          const SizedBox(height: AppSpacing.m),
                          children[2],
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: children[0]),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(flex: 6, child: children[1]),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(flex: 4, child: children[2]),
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

  void _showTemplateDialog() {
    showDialog(
      context: context,
      builder: (context) => AppTemplateDialog(
        onSelect: (title, content) {
          _campaignNameController.text = title;
          _messageController.text = content;
        },
      ),
    );
  }

  Future<void> _importDemoRecipients() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final contents = await file.readAsString();
        _recipientsController.text = contents;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã nhập danh sách từ file: ${result.files.single.name}',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi đọc file: $e')));
    }
  }

  void _showPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chức năng này đang chờ thiết kế chi tiết.'),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bulkMessagingProvider);
    final notifier = ref.read(bulkMessagingProvider.notifier);
    final zaloState = ref.watch(zaloIntegrationProvider);
    final accounts = state.accounts;

    return Row(
      children: [
        const Icon(Icons.near_me_outlined, color: AppColors.primary, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gửi tin nhắn hàng loạt', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tạo và quản lý các chiến dịch gửi tin nhắn Zalo tự động, cá nhân hóa.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            state.complianceWarning != null || state.complianceError != null
                ? Icons.warning_amber_rounded
                : Icons.gpp_good_outlined,
            color:
                state.complianceWarning != null || state.complianceError != null
                ? AppColors.warning
                : AppColors.textMuted,
            size: 28,
          ),
          tooltip:
              state.complianceWarning != null || state.complianceError != null
              ? 'Có khuyến cáo an toàn (Nhấn để xem)'
              : 'Hệ thống an toàn (Nhấn để xem)',
          onPressed: () {
            final ZaloActionType actionType;
            if (state.selectedTab == 0) {
              actionType = ZaloActionType.bulkMessageByPhone;
            } else if (state.selectedTab == 1) {
              actionType = ZaloActionType.bulkMessageToGroup;
            } else {
              actionType = ZaloActionType.bulkMessageToFriends;
            }
            showComplianceWarningsDialog(
              context,
              activeWarning: state.complianceError ?? state.complianceWarning,
              actionType: actionType,
            );
          },
        ),
        const SizedBox(width: AppSpacing.s),
        if (accounts.isNotEmpty)
          SizedBox(
            width: 240,
            child: AppSelectField<String>(
              value: accounts.any((acc) => acc.id == state.selectedAccount?.id)
                  ? state.selectedAccount?.id
                  : (accounts.isNotEmpty ? accounts.first.id : null),
              hintText: 'Chọn tài khoản Zalo...',
              items: accounts.map((acc) {
                final cleanLabel = acc.name.replaceAll(
                    RegExp(r'\s*\([^)]*\)$'),
                    '',
                  );
                  final matchingConnected = zaloState.accounts.firstWhere(
                    (a) => a.id == acc.id,
                    orElse: () => ZaloConnectedAccount(
                      id: acc.id,
                      label: acc.name,
                      connected: acc.isConnected,
                      listenerRunning: false,
                    ),
                  );
                  final avatarUrl = matchingConnected.avatarUrl;

                  return DropdownMenuItem(
                    value: acc.id,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.surfaceMuted,
                          backgroundImage: avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl.isEmpty
                              ? Text(
                                  cleanLabel.isNotEmpty
                                      ? cleanLabel[0].toUpperCase()
                                      : 'A',
                                  style: TextStyle(
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
              onChanged: state.isSending || state.isPolling
                  ? null
                  : (val) {
                      if (val != null) {
                        final acc = state.accounts.firstWhere(
                          (a) => a.id == val,
                        );
                        notifier.selectAccount(acc);
                      }
                    },
            ),
          ),
      ],
    );
  }
}

class _CampaignTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onManageCampaigns;

  const _CampaignTabs({
    required this.selectedIndex,
    required this.onChanged,
    required this.onManageCampaigns,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AppTabs(
              selectedIndex: selectedIndex,
              onTabSelected: onChanged,
              tabs: const [
                AppTabItem(label: 'Gửi theo Số điện thoại', icon: Icons.phone),
                AppTabItem(label: 'Gửi vào nhóm Zalo', icon: Icons.groups_2),
                AppTabItem(label: 'Gửi cho Bạn bè Zalo', icon: Icons.group),
                AppTabItem(label: 'Nhãn phân loại Zalo', icon: Icons.badge),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        TextButton.icon(
          onPressed: onManageCampaigns,
          icon: const Icon(Icons.access_time, size: 17),
          label: Text(
            'Quản lý chiến dịch (0)',
            style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _TargetPanel extends ConsumerWidget {
  final int selectedTab;
  final TextEditingController searchController;
  final TextEditingController recipientsController;
  final bool isSending;
  final VoidCallback onImport;
  final VoidCallback onPlaceholder;

  const _TargetPanel({
    required this.selectedTab,
    required this.searchController,
    required this.recipientsController,
    required this.isSending,
    required this.onImport,
    required this.onPlaceholder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget? filterField;
    Widget? actionButton;

    if (selectedTab == 0) {
      filterField = SizedBox(
        width: 180,
        child: Text(
          'Chế độ: Nhập SĐT thủ công',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      );
      actionButton = AppButton(
        text: 'Nhập từ file (.txt)',
        icon: Icons.description_outlined,
        variant: AppButtonVariant.outline,
        onPressed: isSending ? null : onImport,
      );
    } else if (selectedTab == 1) {
      final groupsState = ref.watch(managedGroupsProvider);
      final selectedAccount = ref.watch(bulkMessagingProvider).selectedAccount;
      final accountId = bulkAccountFilterId(selectedAccount);
      // Synchronize account selection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (groupsState.selectedAccountId != accountId) {
          ref
              .read(managedGroupsProvider.notifier)
              .setSelectedAccountId(accountId);
        }
      });

      final groupItems = groupsState.groups
          .where(
            (g) =>
                accountId.isEmpty ||
                g.accountId == accountId ||
                (accountId.length >= 4 &&
                    g.name.startsWith(
                      '[${accountId.substring(accountId.length - 4)}]',
                    )),
          )
          .map(
            (g) => DropdownMenuItem<ManagedZaloGroup>(
              value: g,
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
                            g.name.isNotEmpty ? g.name[0] : 'G',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      '${g.name} (${g.memberCount} thành viên)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList();

      filterField = Expanded(
        child: AppSelectField<ManagedZaloGroup>(
          hintText: 'Chọn nhóm Zalo',
          items: groupItems,
          onChanged: (group) {
            if (group != null) {
              recipientsController.text = group.groupId;
              ref.read(scanMembersProvider.notifier).selectSavedGroup(group.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã chọn nhóm: ${group.name}')),
              );
            }
          },
        ),
      );
      actionButton = AppButton(
        text: 'Tải lại nhóm',
        icon: Icons.sync,
        variant: AppButtonVariant.outline,
        onPressed: () => ref.read(managedGroupsProvider.notifier).syncGroups(),
      );
    } else if (selectedTab == 2) {
      final friendsState = ref.watch(inviteToGroupProvider);
      final visibleContacts = friendsState.friends.where((c) {
        final q = searchController.text.toLowerCase();
        return q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            c.phone.contains(q);
      }).toList();

      // Synchronize account selection and load friends
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentAccount = bulkAccountFilterId(
          ref.read(bulkMessagingProvider).selectedAccount,
        );
        final inviteNotifier = ref.read(inviteToGroupProvider.notifier);

        if ((friendsState.selectedAccountId ?? '') != currentAccount) {
          inviteNotifier.setAccount(currentAccount);
          inviteNotifier.loadFriends();
        } else if (friendsState.friends.isEmpty && !friendsState.isRunning) {
          inviteNotifier.loadFriends();
        }
      });

      final currentPhones = recipientsController.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      // Assume friend ID or phone. Since friends might not have phone, use ID for recipientsController in this tab.
      final allSelected =
          visibleContacts.isNotEmpty &&
          visibleContacts.every((c) => currentPhones.contains(c.id));

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
                      controller: searchController,
                      hintText: 'Tìm kiếm bạn bè...',
                      onChanged: (val) {
                        // trigger rebuild
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  AppButton(
                    text: 'Tải lại danh bạ',
                    icon: Icons.sync,
                    variant: AppButtonVariant.outline,
                    onPressed: () =>
                        ref.read(inviteToGroupProvider.notifier).loadFriends(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.borderSoft),
            CheckboxListTile(
              title: Text(
                'Chọn tất cả bạn bè (${visibleContacts.length})',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              value: allSelected,
              enabled: !isSending,
              onChanged: (val) {
                if (val == true) {
                  final newPhones = currentPhones.union(
                    visibleContacts
                        .map((c) => c.id)
                        .where((p) => p.isNotEmpty)
                        .toSet(),
                  );
                  recipientsController.text = newPhones.join('\n');
                } else {
                  final newPhones = currentPhones.difference(
                    visibleContacts.map((c) => c.id).toSet(),
                  );
                  recipientsController.text = newPhones.join('\n');
                }
                (context as Element).markNeedsBuild();
              },
              activeColor: AppColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
              ),
            ),
            Divider(height: 1, color: AppColors.borderSoft),
            Expanded(
              child: ListView.separated(
                itemCount: visibleContacts.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: AppColors.borderSoft),
                itemBuilder: (context, index) {
                  final contact = visibleContacts[index];
                  final isChecked = currentPhones.contains(contact.id);
                  return CheckboxListTile(
                    title: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.surfaceMuted,
                          backgroundImage: contact.avatarUrl.isNotEmpty
                              ? NetworkImage(contact.avatarUrl)
                              : null,
                          child: contact.avatarUrl.isEmpty
                              ? Text(
                                  contact.name.isNotEmpty
                                      ? contact.name
                                            .substring(0, 1)
                                            .toUpperCase()
                                      : 'F',
                                  style: TextStyle(
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
                            contact.name,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    subtitle: contact.phone.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(left: 36.0),
                            child: Text(
                              contact.phone,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        : null,
                    value: isChecked,
                    enabled: !isSending,
                    onChanged: (val) {
                      if (val == true) {
                        currentPhones.add(contact.id);
                      } else {
                        currentPhones.remove(contact.id);
                      }
                      recipientsController.text = currentPhones.join('\n');
                      (context as Element).markNeedsBuild();
                    },
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
    } else if (selectedTab == 3) {
      final customersState = ref.watch(customersProvider);
      final uniqueTags = customersState.contacts
          .map((c) => c.tag)
          .where((tag) => tag.isNotEmpty && tag != 'Tất cả')
          .toSet()
          .toList();
      final tagItems = uniqueTags
          .map(
            (tag) => DropdownMenuItem<String>(
              value: tag,
              child: Text(tag, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList();

      filterField = SizedBox(
        width: 200,
        child: AppSelectField<String>(
          hintText: 'Chọn nhãn Zalo',
          items: tagItems,
          onChanged: (tag) {
            if (tag != null) {
              final phones = customersState.contacts
                  .where((c) => c.tag == tag && c.phone.isNotEmpty)
                  .map((c) => c.phone)
                  .toList();
              recipientsController.text = phones.join('\n');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Đã thêm ${phones.length} khách hàng có nhãn "$tag"',
                  ),
                ),
              );
            }
          },
        ),
      );
      actionButton = AppButton(
        text: 'Tải lại danh bạ',
        icon: Icons.sync,
        variant: AppButtonVariant.outline,
        onPressed: () => ref.read(customersProvider.notifier).loadContacts(),
      );
    }

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
                    controller: searchController,
                    hintText: 'Tìm kiếm liên hệ/SĐT...',
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                PopupMenuButton<String>(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: AppSpacing.borderRadiusS,
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.filter_alt_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Lọc'),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'all', child: Text('Tất cả')),
                    const PopupMenuItem(
                      value: 'unsent',
                      child: Text('Chưa nhắn tin'),
                    ),
                    const PopupMenuItem(
                      value: 'success',
                      child: Text('Thành công'),
                    ),
                    const PopupMenuItem(
                      value: 'failure',
                      child: Text('Thất bại'),
                    ),
                  ],
                  onSelected: (value) {
                    // Filter action
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã chọn lọc: $value')),
                    );
                  },
                ),
                const SizedBox(width: AppSpacing.s),
                AppButton(
                  text: 'Bắt đầu chạy',
                  icon: Icons.play_arrow_rounded,
                  onPressed: null,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderSoft),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                if (filterField != null) filterField,
                const Spacer(),
                if (actionButton != null) actionButton,
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderSoft),
          Expanded(
            child: recipientsController.text.trim().isEmpty
                ? const _ManualPhoneEmpty()
                : (selectedTab == 1
                      ? _GroupMembersPreview(
                          groupId: recipientsController.text.trim(),
                        )
                      : _RecipientPreview(controller: recipientsController)),
          ),
        ],
      ),
    );
  }
}

class _GroupMembersPreview extends ConsumerWidget {
  final String groupId;

  const _GroupMembersPreview({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanMembersProvider);

    if (state.isScanning) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.members.isEmpty) {
      return Center(
        child: Text(
          'Không tìm thấy thành viên (hoặc đang chờ tải).',
          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          child: Text(
            'Thành viên nhóm (${state.members.length}):',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Divider(height: 1, color: AppColors.borderSoft),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: state.members.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: AppColors.borderSoft),
            itemBuilder: (context, index) {
              final member = state.members[index];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.surfaceMuted,
                  backgroundImage: member.avatarUrl.isNotEmpty
                      ? NetworkImage(member.avatarUrl)
                      : null,
                  child: member.avatarUrl.isEmpty
                      ? Text(
                          member.name.isNotEmpty
                              ? member.name.substring(0, 1).toUpperCase()
                              : 'M',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : null,
                ),
                title: Text(member.name, style: AppTextStyles.bodyMedium),
                subtitle: member.role != 'Thành viên'
                    ? Text(
                        member.role,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ManualPhoneEmpty extends StatelessWidget {
  const _ManualPhoneEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Text(
              'M',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            'ALPHA CRM - GỬI SĐT THỦ CÔNG',
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            width: 360,
            child: Text(
              'Vui lòng nhập danh sách số điện thoại ở phần soạn thảo bên dưới hoặc bấm nút "Nhập từ file" để tải tệp .txt chứa số điện thoại.',
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientPreview extends StatelessWidget {
  final TextEditingController controller;

  const _RecipientPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final rows = controller.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.m),
      itemCount: rows.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: AppColors.borderSoft),
      itemBuilder: (context, index) {
        return ListTile(
          dense: true,
          leading: const Icon(Icons.phone, color: AppColors.primary, size: 18),
          title: Text(rows[index], style: AppTextStyles.bodyMedium),
        );
      },
    );
  }
}

class _ConfigPanel extends StatelessWidget {
  final BulkMessagingState state;
  final TextEditingController campaignNameController;
  final TextEditingController messageController;
  final TextEditingController minDelayController;
  final TextEditingController maxDelayController;
  final BulkMessagingNotifier notifier;
  final VoidCallback onPlaceholder;
  final VoidCallback onSelectTemplate;

  const _ConfigPanel({
    required this.state,
    required this.campaignNameController,
    required this.messageController,
    required this.minDelayController,
    required this.maxDelayController,
    required this.notifier,
    required this.onPlaceholder,
    required this.onSelectTemplate,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(
                children: [
                  const Icon(
                    Icons.settings_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cấu hình chiến dịch gửi tin',
                          style: AppTextStyles.sectionTitle,
                        ),
                        Text(
                          'Thiết lập tên, tài khoản và nội dung tin nhắn gửi đi',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.borderSoft),
            _Section(
              title: '1. CẤU HÌNH CHUNG',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tên chiến dịch *', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: campaignNameController,
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(
                      hintText: 'VD: Chúc mừng sinh nhật khách hàng tháng 5',
                    ),
                  ),
                  if (state.accounts.isEmpty) ...[
                    const SizedBox(height: AppSpacing.m),
                    const AppAlert(
                      message:
                          'Chưa có tài khoản nào kết nối. Vui lòng vào Cài đặt để đăng nhập.',
                      variant: AppAlertVariant.error,
                    ),
                    const SizedBox(height: AppSpacing.m),
                  ] else ...[
                    const SizedBox(height: AppSpacing.m),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stack = constraints.maxWidth < 420;
                      final fields = [
                        _NumberField(
                          controller: minDelayController,
                          label: 'Delay tối thiểu (s)',
                          onChanged: notifier.setMinDelay,
                        ),
                        _NumberField(
                          controller: maxDelayController,
                          label: 'Delay tối đa (s)',
                          onChanged: notifier.setMaxDelay,
                        ),
                      ];

                      if (stack) {
                        return Column(
                          children: [
                            fields[0],
                            const SizedBox(height: AppSpacing.s),
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
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            _Section(
              title: '2. CẤU HÌNH NỘI DUNG',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Nội dung tin nhắn *',
                          style: AppTextStyles.label,
                        ),
                      ),
                      AppButton(
                        text: 'Chọn tin mẫu',
                        icon: Icons.inventory_2_outlined,
                        variant: AppButtonVariant.outline,
                        onPressed: onSelectTemplate,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _EditorToolbar(controller: messageController),
                  TextField(
                    controller: messageController,
                    maxLines: 7,
                    minLines: 7,
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(
                      hintText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(AppSpacing.radiusS),
                          bottomRight: Radius.circular(AppSpacing.radiusS),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Row(
                    children: [
                      AppButton(
                        text: 'Chọn hình ảnh/file',
                        icon: Icons.attach_file,
                        variant: AppButtonVariant.outline,
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles();
                          if (result != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Đã chọn: ${result.files.single.name}',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(bulkMessagingProvider);
                  final notifier = ref.read(bulkMessagingProvider.notifier);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.isSending || state.isPolling)
                        AppButton(
                          text: state.isPolling
                              ? 'Đang chạy (Hủy)'
                              : 'Dừng gửi',
                          icon: Icons.stop,
                          variant: AppButtonVariant.primary,
                          onPressed: notifier.stopSending,
                        )
                      else
                        AppButton(
                          text: 'Bắt đầu gửi',
                          icon: Icons.send,
                          variant: AppButtonVariant.primary,
                          onPressed: () {
                            if (state.recipientsText.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Vui lòng nhập danh sách người nhận.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            notifier.startSending();
                          },
                        ),

                      if (state.totalCount > 0 ||
                          state.successCount > 0 ||
                          state.failureCount > 0 ||
                          state.logs.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.m),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                title: 'Thành công',
                                value: '${state.successCount}',
                                color: Colors.green,
                                icon: Icons.check_circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MetricCard(
                                title: 'Thất bại',
                                value: '${state.failureCount}',
                                color: Colors.red,
                                icon: Icons.error,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MetricCard(
                                title: 'Đã hủy',
                                value: '${state.cancelledCount}',
                                color: Colors.orange,
                                icon: Icons.cancel,
                              ),
                            ),
                          ],
                        ),
                        if (state.totalCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: LinearProgressIndicator(
                              value:
                                  (state.successCount +
                                      state.failureCount +
                                      state.cancelledCount) /
                                  state.totalCount,
                            ),
                          ),
                        if (state.logs.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.m),
                          SizedBox(
                            height: 200,
                            child: ActivityLogPanel(
                              logs: state.logs,
                              isRunning: state.isSending || state.isPolling,
                              onClear: notifier.clearLogs,
                            ),
                          ),
                        ],
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.m),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.borderRadiusM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.s,
            ),
            child: Row(
              children: [
                Expanded(child: Text(title, style: AppTextStyles.cardTitle)),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderSoft),
          Padding(padding: const EdgeInsets.all(AppSpacing.m), child: child),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<int> onChanged;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppTextStyles.body,
      onChanged: (value) => onChanged(int.tryParse(value) ?? 0),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  final TextEditingController controller;

  const _EditorToolbar({required this.controller});

  void _insertText(String text) {
    final textLength = controller.text.length;
    final selection = controller.selection;
    final start = selection.start != -1 ? selection.start : textLength;
    final end = selection.end != -1 ? selection.end : textLength;

    final newText = controller.text.replaceRange(start, end, text);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  void _wrapText(BuildContext context, String wrapStr) {
    final selection = controller.selection;
    if (selection.start == -1 ||
        selection.end == -1 ||
        selection.start == selection.end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng bôi đen chữ cần định dạng.')),
      );
      return;
    }
    final start = selection.start;
    final end = selection.end;
    final selectedText = controller.text.substring(start, end);
    final newText = controller.text.replaceRange(
      start,
      end,
      wrapStr + selectedText + wrapStr,
    );
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: end + wrapStr.length * 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
          left: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.radiusS),
          topRight: Radius.circular(AppSpacing.radiusS),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _wrapText(context, '**'),
            icon: const Icon(Icons.format_bold, size: 16),
            tooltip: 'Đậm',
          ),
          IconButton(
            onPressed: () => _wrapText(context, '*'),
            icon: const Icon(Icons.format_italic, size: 16),
            tooltip: 'Nghiêng',
          ),
          IconButton(
            onPressed: () => _wrapText(context, '__'),
            icon: const Icon(Icons.format_underlined, size: 16),
            tooltip: 'Gạch chân',
          ),
          IconButton(
            onPressed: () => _wrapText(context, '~~'),
            icon: const Icon(Icons.strikethrough_s, size: 16),
            tooltip: 'Gạch ngang',
          ),
          const VerticalDivider(width: AppSpacing.m),
          _MiniChip(
            icon: Icons.person,
            label: 'Tên',
            tooltip: 'Chèn tên người nhận',
            color: Colors.blue,
            onTap: () => _insertText('{{tên}}'),
          ),
          const SizedBox(width: AppSpacing.xs),
          _MiniChip(
            icon: Icons.phone,
            label: 'SĐT',
            tooltip: 'Chèn số điện thoại người nhận',
            color: Colors.green,
            onTap: () => _insertText('{{sdt}}'),
          ),
          const SizedBox(width: AppSpacing.xs),
          _MiniChip(
            icon: Icons.group,
            label: 'Nhóm',
            tooltip: 'Chèn tên nhóm',
            color: Colors.orange,
            onTap: () => _insertText('{{nhóm}}'),
          ),
          const SizedBox(width: AppSpacing.xs),
          _MiniChip(
            icon: Icons.shuffle,
            label: 'Spintax',
            tooltip: 'Trộn văn bản ngẫu nhiên (VD: {Chào|Hi} bạn)',
            color: Colors.purple,
            onTap: () => _insertText('{A|B|C}'),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;

  const _MiniChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tooltip,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusS,
        child: Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: AppSpacing.borderRadiusS,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 2),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZaloPreview extends StatelessWidget {
  final String message;

  const _ZaloPreview({required this.message});

  List<TextSpan> _parseFormattedText(String text) {
    final processed = ZaloTextFormatter.renderZaloPreview(
      text,
      name: 'Anh/Chị Khách Hàng',
      phone: '0901234567',
      group: 'Nhóm Zalo Demo',
    );

    return [TextSpan(text: processed)];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewportBg = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFDDEAF8);
    final bubbleBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bubbleTextColor = isDark ? Colors.white : AppColors.textPrimary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  'Xem trước hiển thị trên Zalo',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Kiểm tra giao diện tin nhắn trước khi gửi',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.m),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: viewportBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Container(
                    height: 46,
                    decoration: const BoxDecoration(
                      color: AppColors.zaloBlue,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: 18,
                        ),
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'KH',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        const Expanded(
                          child: Text(
                            'Khách hàng Zalo',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        if (message.trim().isNotEmpty)
                          Positioned(
                            left: AppSpacing.m,
                            top: AppSpacing.m,
                            right: AppSpacing.xl,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: bubbleBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.s),
                                child: RichText(
                                  text: TextSpan(
                                    style: AppTextStyles.body.copyWith(
                                      color: bubbleTextColor,
                                    ),
                                    children: _parseFormattedText(message),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: AppSpacing.m,
                          bottom: AppSpacing.m,
                          child: const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppTemplateDialog extends StatefulWidget {
  final void Function(String title, String content) onSelect;

  const AppTemplateDialog({super.key, required this.onSelect});

  @override
  State<AppTemplateDialog> createState() => _AppTemplateDialogState();
}

class _AppTemplateDialogState extends State<AppTemplateDialog> {
  void _showAddTemplateDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AppDialog(
          title: 'Thêm tin mẫu mới',
          icon: Icons.add_box_outlined,
          width: 500,
          actions: [
            AppDialogAction(
              text: 'Hủy',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.pop(ctx),
            ),
            AppDialogAction(
              text: 'Lưu tin mẫu',
              icon: Icons.save,
              onPressed: () {
                final t = titleController.text.trim();
                final c = contentController.text.trim();
                if (t.isNotEmpty && c.isNotEmpty) {
                  setState(() {
                    templates.insert(0, {
                      'title': t,
                      'content': c,
                    });
                  });
                  Navigator.pop(ctx);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Vui lòng nhập đầy đủ Tên và Nội dung',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tên chiến dịch / Tên mẫu *',
                style: AppTextStyles.label,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: titleController,
                style: AppTextStyles.body,
                decoration: const InputDecoration(
                  hintText: 'VD: Khuyến mãi ngày lễ',
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Text('Nội dung tin nhắn *', style: AppTextStyles.label),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: contentController,
                style: AppTextStyles.body,
                maxLines: 5,
                minLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Nhập nội dung mẫu...',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  final List<Map<String, String>> templates = [
    {
      'title': 'Chúc mừng sinh nhật',
      'content':
          'Chào {{tên}}, chúc bạn một ngày sinh nhật thật vui vẻ và hạnh phúc!',
    },
    {
      'title': 'Tri ân khách hàng',
      'content':
          'Cảm ơn {{tên}} đã đồng hành cùng chúng tôi trong thời gian qua. Tặng bạn mã giảm giá 20%.',
    },
    {
      'title': 'Thông báo offline',
      'content':
          'Thông báo: Nhóm {{nhóm}} sẽ có buổi offline vào cuối tuần này. Mọi người sắp xếp thời gian nhé!',
    },
    {
      'title': 'Giới thiệu sản phẩm',
      'content':
          '{Chào|Hi|Hello} {{tên}}, bạn có quan tâm đến sản phẩm mới của bên mình không?',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Quản lý tin mẫu',
      icon: Icons.inventory_2,
      width: 600,
      actions: [
        AppDialogAction(
          text: 'Thêm tin mẫu',
          icon: Icons.add,
          onPressed: _showAddTemplateDialog,
        ),
      ],
      child: SizedBox(
        height: 400,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: templates.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.m),
          itemBuilder: (context, index) {
            final tpl = templates[index];
            return InkWell(
              onTap: () {
                widget.onSelect(tpl['title']!, tpl['content']!);
                Navigator.pop(context);
              },
              borderRadius: AppSpacing.borderRadiusM,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderSoft),
                  borderRadius: AppSpacing.borderRadiusM,
                  color: AppColors.appBackground,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bookmark_outline,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          tpl['title']!,
                          style: AppTextStyles.cardTitle,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      tpl['content']!,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
