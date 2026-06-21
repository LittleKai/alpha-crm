import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
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
import '../../../../../shared/widgets/list_item_tiles.dart';
import '../../../../../shared/widgets/app_tabs.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../providers/bulk_messaging_provider.dart';
import '../../providers/scheduled_campaigns_provider.dart';
import '../../data/scheduled_campaign.dart';
import '../../../../groups/manage/providers/managed_groups_provider.dart';
import '../../../../groups/providers/invite_to_group_provider.dart';
import '../../../../groups/providers/scan_members_provider.dart';
import '../../../../customers/providers/customers_provider.dart';
import '../../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../../../zalo_integration/data/zalo_integration_api.dart';
import '../../../../settings/providers/settings_provider.dart';
import '../../../../../shared/utils/image_helper.dart';

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
  final Set<String> _loadedPhoneNumbers = {};

  @override
  void initState() {
    super.initState();
    // Ensure the logged-in Zalo account pool is loaded when this tab opens so
    // the account selector is populated (other screens trigger this on mount).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(zaloIntegrationProvider.notifier).checkConnection();
    });
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
              onManageCampaigns: () => _showScheduledCampaignsDialog(context),
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
                      loadedPhoneNumbers: _loadedPhoneNumbers,
                      onManualPhonesAdded: (phones) {
                        setState(() {
                          _loadedPhoneNumbers.addAll(phones);
                        });
                      },
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
        final phones = contents.split(RegExp(r'[\n,;\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        setState(() {
          _loadedPhoneNumbers.addAll(phones);
        });
        
        final existing = _recipientsController.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
        _recipientsController.text = {...existing, ...phones}.join('\n');
        
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
                String cleanLabel = acc.name;
                cleanLabel = cleanLabel.replaceAll(
                  RegExp(r'\s*\([^)]*\)$'),
                  '',
                ); // Remove phone
                cleanLabel = cleanLabel.replaceAll(
                  RegExp(r'^\[\d+\]\s*'),
                  '',
                ); // Remove ID prefix

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

class _CampaignTabs extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onManageCampaigns;

  const _CampaignTabs({
    required this.selectedIndex,
    required this.onChanged,
    required this.onManageCampaigns,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(scheduledCampaignsProvider).length;
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
        _ManageCampaignsButton(
          count: pendingCount,
          onTap: onManageCampaigns,
        ),
      ],
    );
  }
}

/// "Quản lý chiến dịch" entry point. Bordered + highlighted when there are queued
/// campaigns, with a red (n) badge showing how many are pending.
class _ManageCampaignsButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ManageCampaignsButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.borderRadiusM,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: active ? 1.5 : 1,
          ),
          borderRadius: AppSpacing.borderRadiusM,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time,
              size: 17,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s),
            Text(
              'Quản lý chiến dịch',
              style: AppTextStyles.label.copyWith(
                color: active ? AppColors.primary : AppColors.textPrimary,
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            if (active) ...[
              const SizedBox(width: AppSpacing.s),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TargetPanel extends ConsumerWidget {
  final int selectedTab;
  final TextEditingController searchController;
  final TextEditingController recipientsController;
  final bool isSending;
  final Set<String> loadedPhoneNumbers;
  final ValueChanged<List<String>> onManualPhonesAdded;
  final VoidCallback onImport;
  final VoidCallback onPlaceholder;

  const _TargetPanel({
    required this.selectedTab,
    required this.searchController,
    required this.recipientsController,
    required this.isSending,
    required this.loadedPhoneNumbers,
    required this.onManualPhonesAdded,
    required this.onImport,
    required this.onPlaceholder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget? filterField;
    Widget? actionButton;

    if (selectedTab == 0) {
      final selectedAccount = ref.watch(bulkMessagingProvider).selectedAccount;
      filterField = AppButton(
        text: 'Thêm thủ công',
        icon: Icons.add,
        variant: AppButtonVariant.outline,
        onPressed: isSending
            ? null
            : () => _showManualPhoneDialog(
                context,
                ref,
                recipientsController,
                bulkAccountFilterId(selectedAccount),
                onManualPhonesAdded,
              ),
      );
      actionButton = AppButton(
        text: 'Nhập từ file (.txt)',
        icon: Icons.description_outlined,
        variant: AppButtonVariant.outline,
        onPressed: isSending ? null : onImport,
      );
    } else if (selectedTab == 1) {
      return _GroupTargetPanel(
        recipientsController: recipientsController,
        isSending: isSending,
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

      // Store the display name/avatar of every selected friend so the campaign
      // can personalize {{tên}} per recipient.
      void syncFriendInfo() {
        final ids = recipientsController.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();
        ref
            .read(bulkMessagingProvider.notifier)
            .replaceRecipientInfo(
              friendsState.friends
                  .where((c) => ids.contains(c.id))
                  .map(
                    (c) => BulkRecipient(
                      id: c.id,
                      name: c.name,
                      avatarUrl: c.avatarUrl,
                      threadType: 'user',
                    ),
                  )
                  .toList(),
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
                      hintText: 'Tìm kiếm bạn bè...',
                      onChanged: (val) {
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
                syncFriendInfo();
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
                  return FriendCheckboxTile(
                    key: ValueKey(contact.id),
                    friend: contact,
                    isChecked: isChecked,
                    enabled: !isSending,
                    onToggle: (id) {
                      if (!isChecked) {
                        currentPhones.add(id);
                      } else {
                        currentPhones.remove(id);
                      }
                      recipientsController.text = currentPhones.join('\n');
                      syncFriendInfo();
                      (context as Element).markNeedsBuild();
                    },
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
              final tagged = customersState.contacts
                  .where((c) => c.tag == tag && c.phone.isNotEmpty)
                  .toList();
              recipientsController.text = tagged.map((c) => c.phone).join('\n');
              ref
                  .read(bulkMessagingProvider.notifier)
                  .replaceRecipientInfo(
                    tagged
                        .map(
                          (c) => BulkRecipient(
                            id: c.phone,
                            name: c.name,
                            threadType: 'user',
                          ),
                        )
                        .toList(),
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Đã thêm ${tagged.length} khách hàng có nhãn "$tag"',
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
                    onChanged: (val) {
                      (context as Element).markNeedsBuild();
                    },
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
                ?filterField,
                const Spacer(),
                ?actionButton,
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderSoft),
          Expanded(
            child: selectedTab == 0 && loadedPhoneNumbers.isEmpty
                ? const _ManualPhoneEmpty()
                : selectedTab == 0
                    ? _RecipientPreview(
                        controller: recipientsController,
                        loadedPhoneNumbers: loadedPhoneNumbers,
                        isSending: isSending,
                        accountId: bulkAccountFilterId(ref.read(bulkMessagingProvider).selectedAccount),
                      )
                    : recipientsController.text.trim().isEmpty
                        ? const _ManualPhoneEmpty()
                        : _RecipientPreview(
                            controller: recipientsController,
                            isSending: isSending,
                            accountId: bulkAccountFilterId(ref.read(bulkMessagingProvider).selectedAccount),
                          ),
          ),
        ],
      ),
    );
  }
}

/// Remove a leading group code such as "[1234] " from the displayed name.
String _stripGroupCode(String name) {
  return name.replaceFirst(RegExp(r'^\s*\[[^\]]*\]\s*'), '').trim();
}

Future<void> _showManualPhoneDialog(
  BuildContext context,
  WidgetRef ref,
  TextEditingController recipientsController,
  String accountId,
  ValueChanged<List<String>> onPhonesAdded,
) async {
  final inputController = TextEditingController();
  final added = await showDialog<List<String>>(
    context: context,
    builder: (ctx) => AppDialog(
      title: 'Thêm số điện thoại thủ công',
      icon: Icons.dialpad,
      width: 500,
      actions: [
        AppDialogAction(
          text: 'Hủy',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.pop(ctx),
        ),
        AppDialogAction(
          text: 'Thêm',
          icon: Icons.add,
          onPressed: () {
            final phones = inputController.text
                .split(RegExp(r'[\n,;\s]+'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            Navigator.pop(ctx, phones);
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Danh sách số điện thoại', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: inputController,
            style: AppTextStyles.body,
            maxLines: 6,
            minLines: 4,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText:
                  'Mỗi số một dòng (hoặc cách nhau bằng dấu phẩy)\nVD:\n0901234567\n0987654321',
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            'Hệ thống sẽ tự tra cứu tên và ảnh đại diện Zalo cho mỗi số.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );

  if (added == null || added.isEmpty) return;

  onPhonesAdded(added);

  // Merge with the existing recipient list (deduplicated, order preserved).
  final existing = recipientsController.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty);
  final merged = <String>{...existing, ...added}.toList();
  recipientsController.text = merged.join('\n');

  final notifier = ref.read(bulkMessagingProvider.notifier);
  for (final phone in added) {
    notifier.upsertRecipientInfo(BulkRecipient(id: phone, threadType: 'user'));
  }

  // Resolve avatar + nickname for the newly-added numbers in the background.
  final baseUrl = ref.read(settingsProvider).settings.zaloBackendBaseUrl;
  final api = ZaloIntegrationApi(baseUrl: baseUrl);
  try {
    for (final phone in added) {
      try {
        final resp = await api.searchUserByPhone(
          phone: phone,
          accountId: accountId,
        );
        if (resp['success'] == true && resp['user'] is Map) {
          final user = Map<String, dynamic>.from(resp['user'] as Map);
          final name = (user['display_name'] ?? user['zalo_name'] ?? '')
              .toString();
          final avatar = sanitizeImageUrl((user['avatar'] ?? '').toString());
          notifier.upsertRecipientInfo(
            BulkRecipient(
              id: phone,
              name: name,
              avatarUrl: avatar,
              threadType: 'user',
            ),
          );
        }
      } catch (_) {
        // Keep the phone without metadata if the lookup fails.
      }
    }
  } finally {
    api.dispose();
  }
}

/// Tab "Gửi vào nhóm Zalo": send into the group thread OR send to each member.
class _GroupTargetPanel extends ConsumerWidget {
  final TextEditingController recipientsController;
  final bool isSending;

  const _GroupTargetPanel({
    required this.recipientsController,
    required this.isSending,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bulk = ref.watch(bulkMessagingProvider);
    final notifier = ref.read(bulkMessagingProvider.notifier);
    final groupsState = ref.watch(managedGroupsProvider);
    final accountId = bulkAccountFilterId(bulk.selectedAccount);
    final mode = bulk.groupSendMode;

    // Keep the managed-groups source filtered to the selected account.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (groupsState.selectedAccountId != accountId) {
        ref
            .read(managedGroupsProvider.notifier)
            .setSelectedAccountId(accountId);
      }
    });

    // Deduplicate by groupId so the dropdown never has two items with the same
    // value (the source of the Flutter dropdown assertion crash).
    final seen = <String>{};
    final groups = groupsState.groups.where((g) {
      final matchesAccount =
          accountId.isEmpty ||
          g.accountId == accountId ||
          (accountId.length >= 4 &&
              g.name.startsWith(
                '[${accountId.substring(accountId.length - 4)}]',
              ));
      return matchesAccount && seen.add(g.groupId);
    }).toList();

    final groupItems = groups
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
                          _stripGroupCode(g.name).isNotEmpty
                              ? _stripGroupCode(g.name)[0]
                              : 'G',
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
                    '${_stripGroupCode(g.name)} (${g.memberCount})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<GroupSendMode>(
                  segments: const [
                    ButtonSegment(
                      value: GroupSendMode.toGroup,
                      label: Text('Gửi tin vào nhóm'),
                      icon: Icon(Icons.forum_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: GroupSendMode.toMembers,
                      label: Text('Gửi cho thành viên'),
                      icon: Icon(Icons.groups_outlined, size: 16),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: isSending
                      ? null
                      : (selection) {
                          recipientsController.text = '';
                          notifier.setGroupSendMode(selection.first);
                        },
                ),
                const SizedBox(height: AppSpacing.m),
                if (mode == GroupSendMode.toMembers)
                  Row(
                    children: [
                      Expanded(
                        child: AppSelectField<ManagedZaloGroup>(
                          hintText: 'Chọn nhóm Zalo',
                          value: bulk.selectedGroup,
                          items: groupItems,
                          onChanged: isSending
                              ? null
                              : (group) {
                                  notifier.selectGroup(group);
                                  recipientsController.text = '';
                                  if (group != null) {
                                    ref
                                        .read(scanMembersProvider.notifier)
                                        .selectSavedGroup(group.groupId);
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      AppButton(
                        text: 'Tải lại nhóm',
                        icon: Icons.sync,
                        variant: AppButtonVariant.outline,
                        onPressed: () => ref
                            .read(managedGroupsProvider.notifier)
                            .syncGroups(),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chọn một hoặc nhiều nhóm để gửi tin vào khung chat nhóm.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      AppButton(
                        text: 'Tải lại nhóm',
                        icon: Icons.sync,
                        variant: AppButtonVariant.outline,
                        onPressed: () => ref
                            .read(managedGroupsProvider.notifier)
                            .syncGroups(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderSoft),
          Expanded(
            child: mode == GroupSendMode.toGroup
                ? _GroupMultiSelector(
                    groups: groups,
                    recipientsController: recipientsController,
                    isSending: isSending,
                  )
                : _GroupMemberSelector(
                    selectedGroup: bulk.selectedGroup,
                    recipientsController: recipientsController,
                    isSending: isSending,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Multi-select list of groups for the "Gửi tin vào nhóm" mode. Each checked
/// group becomes a group-thread recipient.
class _GroupMultiSelector extends ConsumerWidget {
  final List<ManagedZaloGroup> groups;
  final TextEditingController recipientsController;
  final bool isSending;

  const _GroupMultiSelector({
    required this.groups,
    required this.recipientsController,
    required this.isSending,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(bulkMessagingProvider.notifier);

    if (groups.isEmpty) {
      return Center(
        child: Text(
          'Chưa có nhóm nào. Nhấn "Tải lại nhóm" để đồng bộ.',
          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    final selectedIds = recipientsController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final allSelected =
        groups.isNotEmpty &&
        groups.every((g) => selectedIds.contains(g.groupId));

    void sync(Set<String> ids) {
      recipientsController.text = ids.join('\n');
      notifier.replaceRecipientInfo(
        groups
            .where((g) => ids.contains(g.groupId))
            .map(
              (g) => BulkRecipient(
                id: g.groupId,
                name: _stripGroupCode(g.name),
                avatarUrl: g.avatarUrl,
                threadType: 'group',
              ),
            )
            .toList(),
      );
      (context as Element).markNeedsBuild();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          dense: true,
          title: Text(
            'Chọn tất cả nhóm (${groups.length})',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          value: allSelected,
          enabled: !isSending,
          onChanged: (val) {
            if (val == true) {
              sync(groups.map((g) => g.groupId).toSet());
            } else {
              sync(<String>{});
            }
          },
          activeColor: AppColors.primary,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        ),
        Divider(height: 1, color: AppColors.borderSoft),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: groups.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: AppColors.borderSoft),
            itemBuilder: (context, index) {
              final g = groups[index];
              final isChecked = selectedIds.contains(g.groupId);
              return CheckboxListTile(
                dense: true,
                value: isChecked,
                enabled: !isSending,
                onChanged: (val) {
                  final next = Set<String>.from(selectedIds);
                  if (val == true) {
                    next.add(g.groupId);
                  } else {
                    next.remove(g.groupId);
                  }
                  sync(next);
                },
                title: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.surfaceMuted,
                      backgroundImage: g.avatarUrl.isNotEmpty
                          ? NetworkImage(g.avatarUrl)
                          : null,
                      child: g.avatarUrl.isEmpty
                          ? const Icon(
                              Icons.groups_2,
                              size: 16,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        _stripGroupCode(g.name),
                        style: AppTextStyles.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    '${g.memberCount} thành viên',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
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
    );
  }
}

class _GroupMemberSelector extends ConsumerWidget {
  final ManagedZaloGroup? selectedGroup;
  final TextEditingController recipientsController;
  final bool isSending;

  const _GroupMemberSelector({
    required this.selectedGroup,
    required this.recipientsController,
    required this.isSending,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(scanMembersProvider);
    final notifier = ref.read(bulkMessagingProvider.notifier);
    final accountId = bulkAccountFilterId(ref.read(bulkMessagingProvider).selectedAccount);

    if (selectedGroup == null) {
      return Center(
        child: Text(
          'Chọn một nhóm để tải danh sách thành viên.',
          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }
    if (scanState.isScanning) {
      return const Center(child: CircularProgressIndicator());
    }
    if (scanState.members.isEmpty) {
      return Center(
        child: Text(
          'Không tìm thấy thành viên (hoặc đang chờ tải).',
          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    final members = scanState.members;
    
    bool isSelf(String id) {
      if (accountId.isEmpty) return false;
      return id == accountId;
    }
    
    final selectableMembers = members.where((m) => !isSelf(m.id)).toList();

    final selectedIds = recipientsController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final allSelected =
        selectableMembers.isNotEmpty && selectableMembers.every((m) => selectedIds.contains(m.id));

    void sync(Set<String> ids) {
      recipientsController.text = ids.join('\n');
      notifier.replaceRecipientInfo(
        members
            .where((m) => ids.contains(m.id))
            .map(
              (m) => BulkRecipient(
                id: m.id,
                name: m.name,
                avatarUrl: m.avatarUrl,
                threadType: 'user',
              ),
            )
            .toList(),
      );
      (context as Element).markNeedsBuild();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          dense: true,
          title: Text(
            'Chọn tất cả thành viên (${members.length})',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          value: allSelected,
          enabled: !isSending,
          onChanged: (val) {
            final next = Set<String>.from(selectedIds);
            if (val == true) {
              next.addAll(selectableMembers.map((m) => m.id));
            } else {
              next.removeAll(selectableMembers.map((m) => m.id));
            }
            sync(next);
          },
          activeColor: AppColors.primary,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        ),
        Divider(height: 1, color: AppColors.borderSoft),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: members.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: AppColors.borderSoft),
            itemBuilder: (context, index) {
              final member = members[index];
              final self = isSelf(member.id);
              final isChecked = self ? false : selectedIds.contains(member.id);
              return CheckboxListTile(
                dense: true,
                value: isChecked,
                enabled: !isSending && !self,
                onChanged: (val) {
                  if (self) return;
                  final next = Set<String>.from(selectedIds);
                  if (val == true) {
                    next.add(member.id);
                  } else {
                    next.remove(member.id);
                  }
                  sync(next);
                },
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
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        member.name, 
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: self ? AppColors.textMuted : null,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: member.role != 'Thành viên' || self
                    ? Padding(
                        padding: const EdgeInsets.only(left: 36),
                        child: Text(
                          self ? 'Tài khoản của bạn' : member.role,
                          style: AppTextStyles.caption.copyWith(
                            color: self ? AppColors.warning : AppColors.primary,
                          ),
                        ),
                      )
                    : null,
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

class _RecipientPreview extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final Set<String>? loadedPhoneNumbers;
  final bool isSending;
  final String accountId;

  const _RecipientPreview({
    required this.controller,
    this.loadedPhoneNumbers,
    required this.isSending,
    required this.accountId,
  });

  @override
  ConsumerState<_RecipientPreview> createState() => _RecipientPreviewState();
}

class _RecipientPreviewState extends ConsumerState<_RecipientPreview> {
  @override
  Widget build(BuildContext context) {
    final info = ref.watch(bulkMessagingProvider).recipientInfo;
    
    // For Tab 0 (where loadedPhoneNumbers is provided), we use it to show all items.
    // For Tab 3 (where it is null), we just use the controller's text.
    final allItems = widget.loadedPhoneNumbers?.toList() ?? 
        widget.controller.text.split('\n').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
        
    final selectedIds = widget.controller.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();

    // Check if the item is the current account (to disable it)
    bool isSelf(String id) {
      if (widget.accountId.isEmpty) return false;
      return id == widget.accountId; // In Tab 0, ID is usually phone number
    }

    final selectableItems = allItems.where((id) => !isSelf(id)).toList();
    final allSelected = selectableItems.isNotEmpty && selectableItems.every((id) => selectedIds.contains(id));

    void syncController(Set<String> newSelected) {
      widget.controller.text = newSelected.join('\n');
      setState(() {});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.loadedPhoneNumbers != null) ...[
          CheckboxListTile(
            dense: true,
            title: Text(
              'Chọn tất cả (${allItems.length})',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            value: allSelected,
            enabled: !widget.isSending,
            onChanged: (val) {
              final next = Set<String>.from(selectedIds);
              if (val == true) {
                next.addAll(selectableItems);
              } else {
                next.removeAll(selectableItems);
              }
              syncController(next);
            },
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          ),
          Divider(height: 1, color: AppColors.borderSoft),
        ],
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: allItems.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: AppColors.borderSoft),
            itemBuilder: (context, index) {
              final id = allItems[index];
              final meta = info[id];
              final name = meta?.name ?? '';
              final avatarUrl = meta?.avatarUrl ?? '';
              final self = isSelf(id);
              final isChecked = self ? false : selectedIds.contains(id);

              return CheckboxListTile(
                dense: true,
                value: isChecked,
                enabled: !widget.isSending && !self,
                onChanged: (val) {
                  if (self) return;
                  final next = Set<String>.from(selectedIds);
                  if (val == true) {
                    next.add(id);
                  } else {
                    next.remove(id);
                  }
                  syncController(next);
                },
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                title: Row(
                  children: [
                    avatarUrl.isNotEmpty
                        ? CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.surfaceMuted,
                            backgroundImage: NetworkImage(avatarUrl),
                          )
                        : (name.isNotEmpty
                              ? CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.surfaceMuted,
                                  child: Text(
                                    name.substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.phone,
                                  color: AppColors.primary,
                                  size: 18,
                                )),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        name.isNotEmpty ? name : id,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: self ? AppColors.textMuted : null,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: name.isNotEmpty || self
                    ? Padding(
                        padding: const EdgeInsets.only(left: 36),
                        child: Text(
                          self ? 'Tài khoản của bạn' : id,
                          style: AppTextStyles.caption.copyWith(
                            color: self ? AppColors.warning : AppColors.textMuted,
                          ),
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
            _ScheduleSection(
              scheduledAt: state.scheduledAt,
              enabled: !state.isSending && !state.isPolling,
              onChanged: notifier.setScheduledAt,
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
                          text: state.scheduledAt != null
                              ? 'Hẹn giờ gửi'
                              : 'Bắt đầu gửi',
                          icon: state.scheduledAt != null
                              ? Icons.schedule_send
                              : Icons.send,
                          variant: AppButtonVariant.primary,
                          // Block execution unless there is at least one valid
                          // recipient AND message content.
                          onPressed:
                              (!state.hasValidRecipients ||
                                  state.messageText.trim().isEmpty)
                              ? null
                              : () {
                                  if (state.scheduledAt == null) {
                                    notifier.startSending();
                                    return;
                                  }
                                  // Snapshot the form and hand it to the queue,
                                  // then reset the picker so the form is free for
                                  // the next campaign.
                                  final snapshot =
                                      notifier.buildScheduledSnapshot();
                                  if (snapshot == null) return;
                                  ref
                                      .read(
                                        scheduledCampaignsProvider.notifier,
                                      )
                                      .arm(snapshot);
                                  notifier.setScheduledAt(null);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Đã thêm vào hàng đợi — sẽ gửi lúc '
                                        '${DateFormat('HH:mm dd/MM/yyyy').format(snapshot.scheduledAt)}.',
                                      ),
                                    ),
                                  );
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

/// Optional "schedule send" section. Uses Flutter's built-in date/time pickers;
/// the chosen time is stored in the provider and armed via the start button.
class _ScheduleSection extends StatelessWidget {
  final DateTime? scheduledAt;
  final bool enabled;
  final ValueChanged<DateTime?> onChanged;

  const _ScheduleSection({
    required this.scheduledAt,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final on = scheduledAt != null;
    return _Section(
      title: '3. HẸN GIỜ GỬI (TÙY CHỌN)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: on,
            activeThumbColor: AppColors.primary,
            title: Text('Hẹn giờ gửi tự động', style: AppTextStyles.bodyMedium),
            subtitle: Text(
              'Máy phải bật và ứng dụng phải mở tới thời điểm gửi.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
            onChanged: enabled
                ? (val) {
                    if (val) {
                      _pickSchedule(context, scheduledAt, onChanged);
                    } else {
                      onChanged(null);
                    }
                  }
                : null,
          ),
          if (on) ...[
            const SizedBox(height: AppSpacing.s),
            InkWell(
              onTap: enabled
                  ? () => _pickSchedule(context, scheduledAt, onChanged)
                  : null,
              borderRadius: AppSpacing.borderRadiusS,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.m,
                  vertical: AppSpacing.s,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: AppSpacing.borderRadiusS,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        DateFormat('HH:mm  •  dd/MM/yyyy').format(scheduledAt!),
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                    if (enabled)
                      Icon(
                        Icons.edit_calendar,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Restyle the built-in Material date/time pickers to the app's look: dark slate
/// header (matching [AppDialog]), brand-primary selection, app surface, rounded
/// corners. Keeps native behavior + Vietnamese locale + 24h format intact.
Widget _appPickerTheme(BuildContext context, Widget? child) {
  const radius = 18.0;
  const headerDark = Color(0xFF0F172A);
  final base = Theme.of(context);
  final dialogShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
  );

  return Theme(
    data: base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        headerBackgroundColor: headerDark,
        headerForegroundColor: Colors.white,
        shape: dialogShape,
        todayBorder: const BorderSide(color: AppColors.primary),
        elevation: 8,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        dialBackgroundColor: AppColors.surfaceMuted,
        hourMinuteColor: AppColors.surfaceMuted,
        shape: dialogShape,
        hourMinuteShape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusM,
        ),
      ),
      dialogTheme: DialogThemeData(shape: dialogShape),
    ),
    child: child!,
  );
}

/// Show a date picker then a time picker, validate the result is in the future,
/// and report the combined [DateTime] (or do nothing if cancelled/invalid).
Future<void> _pickSchedule(
  BuildContext context,
  DateTime? current,
  ValueChanged<DateTime?> onChanged,
) async {
  final now = DateTime.now();
  final base = (current != null && current.isAfter(now))
      ? current
      : now.add(const Duration(hours: 1));

  final date = await showDatePicker(
    context: context,
    initialDate: base,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 365)),
    builder: _appPickerTheme,
  );
  if (date == null || !context.mounted) return;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(base),
    builder: _appPickerTheme,
  );
  if (time == null || !context.mounted) return;

  final picked = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  if (!picked.isAfter(now)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vui lòng chọn thời điểm trong tương lai.')),
    );
    return;
  }
  onChanged(picked);
}

void _showScheduledCampaignsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const _ScheduledCampaignsDialog(),
  );
}

class _ScheduledCampaignsDialog extends ConsumerWidget {
  const _ScheduledCampaignsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(scheduledCampaignsProvider);
    final notifier = ref.read(scheduledCampaignsProvider.notifier);

    return AppDialog(
      title: 'Quản lý chiến dịch hẹn giờ',
      icon: Icons.access_time,
      width: 640,
      actions: [
        AppDialogAction(
          text: 'Đóng',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.pop(context),
        ),
      ],
      child: SizedBox(
        height: 420,
        child: jobs.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      'Chưa có chiến dịch nào đang chờ gửi.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: jobs.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
                itemBuilder: (context, index) => _ScheduledCampaignTile(
                  job: jobs[index],
                  notifier: notifier,
                ),
              ),
      ),
    );
  }
}

String _relativeTimeText(DateTime at) {
  final diff = at.difference(DateTime.now());
  if (diff.isNegative) return 'đã qua giờ hẹn';
  if (diff.inMinutes < 1) return 'còn dưới 1 phút';
  if (diff.inMinutes < 60) return 'còn ${diff.inMinutes} phút';
  if (diff.inHours < 24) {
    return 'còn ${diff.inHours} giờ ${diff.inMinutes % 60} phút';
  }
  return 'còn ${diff.inDays} ngày';
}

class _ScheduledCampaignTile extends StatelessWidget {
  final ScheduledCampaign job;
  final ScheduledCampaignsNotifier notifier;

  const _ScheduledCampaignTile({required this.job, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final (chipText, chipColor) = switch (job.status) {
      ScheduledStatus.pending => ('Đang chờ', AppColors.primary),
      ScheduledStatus.missed => ('Đã lỡ giờ', AppColors.warning),
      ScheduledStatus.failed => ('Gửi lỗi', Colors.red),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderSoft),
        borderRadius: AppSpacing.borderRadiusM,
        color: AppColors.appBackground,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        job.name.isNotEmpty ? job.name : '(Chiến dịch không tên)',
                        style: AppTextStyles.cardTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: 0.12),
                        borderRadius: AppSpacing.borderRadiusS,
                      ),
                      child: Text(
                        chipText,
                        style: AppTextStyles.caption.copyWith(
                          color: chipColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${DateFormat('HH:mm  •  dd/MM/yyyy').format(job.scheduledAt)}'
                      '  (${_relativeTimeText(job.scheduledAt)})',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${job.isGroupMessage ? "Gửi vào nhóm" : "Gửi cá nhân"} • '
                  '${job.recipients.length} người nhận',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            color: AppColors.primary,
            tooltip: 'Gửi ngay',
            onPressed: () => notifier.sendNow(job.id),
          ),
          IconButton(
            icon: const Icon(Icons.edit_calendar, size: 18),
            color: AppColors.textSecondary,
            tooltip: 'Đổi giờ gửi',
            onPressed: () => _pickSchedule(
              context,
              job.scheduledAt,
              (dt) {
                if (dt != null) notifier.reschedule(job.id, dt);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.red,
            tooltip: 'Xóa khỏi hàng đợi',
            onPressed: () => notifier.cancel(job.id),
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
                    templates.insert(0, {'title': t, 'content': c});
                  });
                  Navigator.pop(ctx);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập đầy đủ Tên và Nội dung'),
                    ),
                  );
                }
              },
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tên chiến dịch / Tên mẫu *', style: AppTextStyles.label),
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
                        Text(tpl['title']!, style: AppTextStyles.cardTitle),
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
