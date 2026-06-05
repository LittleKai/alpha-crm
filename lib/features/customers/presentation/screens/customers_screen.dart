import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/routing/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../mock/mock_contacts.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_metric_card.dart';
import '../../../../shared/widgets/app_search_field.dart';
import '../../../../shared/widgets/app_select_field.dart';
import '../../../../shared/widgets/app_table.dart';
import '../../providers/customers_provider.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _PipelineItem {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _PipelineItem({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });
}

class _CustomerPipelineCard extends StatelessWidget {
  final _PipelineItem item;
  final int percent;

  const _CustomerPipelineCard({required this.item, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: item.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.75),
              borderRadius: AppSpacing.borderRadiusS,
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      item.count.toString(),
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: item.color,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      '$percent%',
                      style: AppTextStyles.captionBold.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedContactsBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onClear;
  final VoidCallback? onExport;
  final VoidCallback onStartCampaign;

  const _SelectedContactsBar({
    required this.selectedCount,
    required this.onClear,
    required this.onExport,
    required this.onStartCampaign,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      backgroundColor: AppColors.primarySoft,
      child: Wrap(
        spacing: AppSpacing.s,
        runSpacing: AppSpacing.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.s,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.borderRadiusPill,
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Text(
              '$selectedCount khách hàng đã chọn',
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          AppButton(
            text: 'Gửi chiến dịch',
            icon: Icons.near_me_outlined,
            onPressed: onStartCampaign,
          ),
          AppButton(
            text: 'Xuất CSV',
            icon: Icons.download_outlined,
            variant: AppButtonVariant.outline,
            onPressed: onExport,
          ),
          AppButton(
            text: 'Bỏ chọn',
            icon: Icons.close_rounded,
            variant: AppButtonVariant.outline,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _CustomerIdentity extends StatelessWidget {
  final Contact contact;

  const _CustomerIdentity({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ContactAvatar(name: contact.name, size: 32),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: Text(
            contact.name,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ContactDetailPanel extends StatelessWidget {
  final Contact contact;
  final VoidCallback onClose;
  final VoidCallback onStartMessaging;

  const _ContactDetailPanel({
    required this.contact,
    required this.onClose,
    required this.onStartMessaging,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey('customer_detail_panel'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                _ContactAvatar(name: contact.name, size: 48),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        contact.phone,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderSoft),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chi tiết khách hàng', style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSpacing.m),
                _DetailRow(
                  icon: Icons.business_center_outlined,
                  label: 'Nhóm',
                  value: contact.group,
                ),
                _DetailRow(
                  icon: Icons.local_offer_outlined,
                  label: 'Nhãn / lĩnh vực',
                  value: contact.tag,
                ),
                _DetailRow(
                  icon: Icons.source_outlined,
                  label: 'Nguồn',
                  value: contact.source,
                ),
                _DetailRow(
                  icon: Icons.verified_outlined,
                  label: 'Trạng thái',
                  value: contact.status,
                ),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Ngày tạo',
                  value: DateFormat('dd/MM/yyyy').format(contact.createdAt),
                ),
                const SizedBox(height: AppSpacing.m),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.m),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: AppSpacing.borderRadiusM,
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Text(
                    'Gợi ý: kiểm tra nhãn, trạng thái và lịch sử tương tác trước khi đưa khách hàng vào chiến dịch mới.',
                    style: AppTextStyles.caption.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderSoft),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: [
                AppButton(
                  text: 'Mở live chat',
                  icon: Icons.chat_bubble_outline,
                  onPressed: onStartMessaging,
                ),
                AppButton(
                  text: 'Tạo segment',
                  icon: Icons.bookmark_add_outlined,
                  variant: AppButtonVariant.outline,
                  onPressed: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.iconMuted, size: 17),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Chưa có dữ liệu' : value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactAvatar extends StatelessWidget {
  final String name;
  final double size;

  const _ContactAvatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'K' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.success],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size >= 44 ? 16 : 10),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size >= 44 ? 18 : 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _activeContactId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customersProvider);
    final notifier = ref.read(customersProvider.notifier);
    final filteredContacts = _filteredContacts(state);
    final isEmpty = state.contacts.isEmpty;
    final activeContact = _activeContact(filteredContacts, state.contacts);

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          ResponsiveBreakpoints.isMobile(context) ? AppSpacing.m : AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.l),
            _buildStatsGrid(isEmpty, state.contacts.length),
            const SizedBox(height: AppSpacing.l),
            _buildPipelineSummary(filteredContacts),
            const SizedBox(height: AppSpacing.l),
            _buildToolbar(state, notifier),
            const SizedBox(height: AppSpacing.l),
            _buildCustomersWorkspace(
              state,
              filteredContacts,
              isEmpty,
              activeContact,
            ),
            if (state.selectedIds.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.l),
              _SelectedContactsBar(
                selectedCount: state.selectedIds.length,
                onClear: () {
                  for (final id in state.selectedIds.toList()) {
                    notifier.toggleContactSelection(id);
                  }
                },
                onExport: state.contacts.isEmpty
                    ? null
                    : notifier.exportContacts,
                onStartCampaign: () => context.go(AppRoutes.messagingBulk),
              ),
            ],
            if (state.exportCsv != null && state.exportCsv!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.l),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CSV export preview',
                      style: AppTextStyles.sectionTitle,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    SelectableText(
                      state.exportCsv!,
                      maxLines: 8,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Contact> _filteredContacts(CustomersState state) {
    return state.contacts.where((contact) {
      final query = state.searchQuery.toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          contact.name.toLowerCase().contains(query) ||
          contact.phone.contains(query);
      final matchesGroup =
          state.selectedGroup == 'Tất cả' ||
          contact.group == state.selectedGroup;
      final matchesTag =
          state.selectedTag == 'Tất cả' || contact.tag == state.selectedTag;
      final matchesStatus =
          state.selectedStatus == 'Tất cả' ||
          contact.status == state.selectedStatus;

      return matchesSearch && matchesGroup && matchesTag && matchesStatus;
    }).toList();
  }

  Contact? _activeContact(
    List<Contact> filteredContacts,
    List<Contact> allContacts,
  ) {
    final id = _activeContactId;
    if (id == null) return null;

    for (final contact in filteredContacts) {
      if (contact.id == id) return contact;
    }
    for (final contact in allContacts) {
      if (contact.id == id) return contact;
    }
    return null;
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.people_alt_outlined,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CRM Khách Hàng', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Hệ thống quản trị và chăm sóc khách hàng Zalo chuyên nghiệp',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isEmpty, int totalContacts) {
    final cards = [
      AppMetricCard(
        title: 'Tổng số khách hàng',
        value: isEmpty ? '0' : totalContacts.toString(),
        icon: Icons.group_outlined,
        iconColor: AppColors.primary,
        iconBackgroundColor: AppColors.primarySoft,
      ),
      AppMetricCard(
        title: 'Khách hàng tiềm năng',
        value: '0',
        icon: Icons.group_outlined,
        iconColor: AppColors.warning,
        iconBackgroundColor: AppColors.warningSoft,
      ),
      AppMetricCard(
        title: 'Khách hàng VIP',
        value: '0',
        icon: Icons.group_outlined,
        iconColor: Color(0xFFA855F7),
        iconBackgroundColor: AppColors.purpleSoft,
      ),
      AppMetricCard(
        title: 'Đã gửi tin nhắn (Tỷ lệ)',
        value: '0 / 0 (0%)',
        icon: Icons.phone_in_talk_outlined,
        iconColor: AppColors.success,
        iconBackgroundColor: AppColors.successSoft,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 640
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.m,
            mainAxisSpacing: AppSpacing.m,
            mainAxisExtent: 76,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }

  Widget _buildPipelineSummary(List<Contact> contacts) {
    final total = contacts.length;
    final items = [
      _PipelineItem(
        label: 'Chưa gửi',
        count: _countStatus(contacts, 'Chưa gửi'),
        icon: Icons.radio_button_unchecked_rounded,
        color: AppColors.textMuted,
      ),
      _PipelineItem(
        label: 'Đã gửi',
        count: _countStatus(contacts, 'Đã gửi'),
        icon: Icons.near_me_outlined,
        color: AppColors.primary,
      ),
      _PipelineItem(
        label: 'Thành công',
        count: _countStatus(contacts, 'Thành công'),
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
      ),
      _PipelineItem(
        label: 'Thất bại',
        count: _countStatus(contacts, 'Thất bại'),
        icon: Icons.error_outline_rounded,
        color: AppColors.error,
      ),
    ];

    return AppCard(
      key: const ValueKey('customers_pipeline_summary'),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  'Pipeline khách hàng',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              Text(
                '$total khách hàng',
                style: AppTextStyles.captionBold.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 520
                  ? 2
                  : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpacing.m,
                  mainAxisSpacing: AppSpacing.m,
                  mainAxisExtent: 84,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final percent = total == 0
                      ? 0
                      : ((item.count / total) * 100).round();
                  return _CustomerPipelineCard(item: item, percent: percent);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  int _countStatus(List<Contact> contacts, String status) {
    return contacts.where((contact) => contact.status == status).length;
  }

  Widget _buildToolbar(CustomersState state, CustomersNotifier notifier) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final groups = [
      'Tất cả',
      'Khách hàng VIP',
      'Khách hàng tiềm năng',
      'Đối tác',
    ];
    final tags = [
      'Tất cả',
      'Bất động sản',
      'Tài chính',
      'Công nghệ',
      'Giáo dục',
      'Thời trang',
    ];
    final statuses = ['Tất cả', 'Chưa gửi', 'Đã gửi', 'Thất bại', 'Thành công'];

    final search = AppSearchField(
      hintText: 'Tìm kiếm theo tên hoặc SĐT...',
      controller: _searchController,
      onChanged: notifier.setSearchQuery,
    );
    final filters = [
      AppSelectField<String>(
        value: state.selectedSegmentId,
        items: [
          const DropdownMenuItem(value: '', child: Text('Tất cả segment')),
          ...state.segments.map(
            (segment) =>
                DropdownMenuItem(value: segment.id, child: Text(segment.name)),
          ),
        ],
        onChanged: (value) {
          if (value != null) notifier.setSelectedSegment(value);
        },
      ),
      AppSelectField<String>(
        value: state.selectedGroup,
        items: groups
            .map((group) => DropdownMenuItem(value: group, child: Text(group)))
            .toList(),
        onChanged: (value) {
          if (value != null) notifier.setSelectedGroup(value);
        },
      ),
      AppSelectField<String>(
        value: state.selectedTag,
        items: tags
            .map((tag) => DropdownMenuItem(value: tag, child: Text(tag)))
            .toList(),
        onChanged: (value) {
          if (value != null) notifier.setSelectedTag(value);
        },
      ),
      AppSelectField<String>(
        value: state.selectedStatus,
        items: statuses
            .map(
              (status) => DropdownMenuItem(value: status, child: Text(status)),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) notifier.setSelectedStatus(value);
        },
      ),
    ];
    final actions = [
      AppButton(
        text: 'Import Excel/CSV',
        icon: Icons.description_outlined,
        variant: AppButtonVariant.outline,
        onPressed: () => _importDemoContacts(notifier),
      ),
      AppButton(
        text: 'Xuất Excel',
        icon: Icons.description_outlined,
        variant: AppButtonVariant.outline,
        onPressed: state.contacts.isEmpty ? null : notifier.exportContacts,
      ),
      AppButton(
        text: 'Lưu segment',
        icon: Icons.bookmark_add_outlined,
        variant: AppButtonVariant.outline,
        onPressed: () => _showSaveSegmentDialog(notifier),
      ),
      AppButton(
        text: 'Thêm liên hệ',
        icon: Icons.add_rounded,
        onPressed: () => _showAddContactDialog(context, notifier),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final filterWidth = isMobile
            ? constraints.maxWidth
            : constraints.maxWidth >= 1100
            ? 170.0
            : 220.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...filters.map(
                  (filter) => SizedBox(width: filterWidth, child: filter),
                ),
                ...actions,
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomersWorkspace(
    CustomersState state,
    List<Contact> filteredContacts,
    bool isEmpty,
    Contact? activeContact,
  ) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    if (isMobile || activeContact == null) {
      return Column(
        children: [
          _buildMainContent(state, filteredContacts, isEmpty),
          if (activeContact != null) ...[
            const SizedBox(height: AppSpacing.m),
            _ContactDetailPanel(
              contact: activeContact,
              onClose: () => setState(() => _activeContactId = null),
              onStartMessaging: () => context.go(AppRoutes.messagingLiveChat),
            ),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1080) {
          return Column(
            children: [
              _buildMainContent(state, filteredContacts, isEmpty),
              const SizedBox(height: AppSpacing.m),
              _ContactDetailPanel(
                contact: activeContact,
                onClose: () => setState(() => _activeContactId = null),
                onStartMessaging: () => context.go(AppRoutes.messagingLiveChat),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildMainContent(state, filteredContacts, isEmpty),
            ),
            const SizedBox(width: AppSpacing.m),
            SizedBox(
              width: 340,
              child: _ContactDetailPanel(
                contact: activeContact,
                onClose: () => setState(() => _activeContactId = null),
                onStartMessaging: () => context.go(AppRoutes.messagingLiveChat),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainContent(
    CustomersState state,
    List<Contact> filteredContacts,
    bool isEmpty,
  ) {
    if (state.errorMessage != null) {
      return AppCard(
        height: 360,
        child: Center(
          child: Text(
            state.errorMessage!,
            style: AppTextStyles.body.copyWith(color: AppColors.errorText),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (isEmpty) {
      return AppCard(
        child: AppEmptyState(
          icon: Icons.group_outlined,
          title: 'Chưa có liên hệ nào',
          description:
              'Import từ Excel/CSV, thêm thủ công, hoặc tải từ bạn bè Zalo.',
          height: 360,
          actions: [
            AppButton(
              text: 'Import file',
              icon: Icons.description_outlined,
              variant: AppButtonVariant.outline,
              onPressed: () => _showPlaceholder(
                'Chức năng import sẽ được triển khai khi có flow file picker.',
              ),
            ),
            AppButton(
              text: 'Thêm thủ công',
              icon: Icons.add_rounded,
              onPressed: () => _showAddContactDialog(
                context,
                ref.read(customersProvider.notifier),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 420,
        child: AppTable(
          isEmpty: filteredContacts.isEmpty,
          emptyTitle: 'Không tìm thấy liên hệ',
          emptyDescription: 'Không có liên hệ nào khớp với bộ lọc hiện tại.',
          columns: const [
            AppTableColumn(label: 'Họ và tên', size: ColumnSize.L),
            AppTableColumn(label: 'Số điện thoại', size: ColumnSize.M),
            AppTableColumn(label: 'Nhóm', size: ColumnSize.M),
            AppTableColumn(label: 'Nhãn / Lĩnh vực', size: ColumnSize.M),
            AppTableColumn(label: 'Nguồn', size: ColumnSize.S),
            AppTableColumn(label: 'Trạng thái', size: ColumnSize.S),
            AppTableColumn(label: 'Ngày tạo', size: ColumnSize.S),
          ],
          rows: filteredContacts
              .map((contact) => _buildContactRow(contact, state))
              .toList(),
        ),
      ),
    );
  }

  DataRow _buildContactRow(Contact contact, CustomersState state) {
    final notifier = ref.read(customersProvider.notifier);
    final isActive = _activeContactId == contact.id;
    final isSelected = state.selectedIds.contains(contact.id);

    void activateContact() {
      setState(() => _activeContactId = contact.id);
    }

    return DataRow(
      selected: isSelected,
      color: WidgetStateProperty.resolveWith((states) {
        if (isActive) {
          return AppColors.primarySoft.withValues(alpha: 0.6);
        }
        if (states.contains(WidgetState.selected)) {
          return AppColors.primarySoft.withValues(alpha: 0.35);
        }
        return null;
      }),
      onSelectChanged: (_) {
        notifier.toggleContactSelection(contact.id);
        activateContact();
      },
      cells: [
        DataCell(_CustomerIdentity(contact: contact), onTap: activateContact),
        DataCell(
          Text(contact.phone, style: AppTextStyles.body),
          onTap: activateContact,
        ),
        DataCell(
          Text(contact.group, style: AppTextStyles.body),
          onTap: activateContact,
        ),
        DataCell(
          Text(contact.tag, style: AppTextStyles.body),
          onTap: activateContact,
        ),
        DataCell(_buildSourceBadge(contact.source), onTap: activateContact),
        DataCell(_buildStatusBadge(contact.status), onTap: activateContact),
        DataCell(
          Text(
            DateFormat('dd/MM/yyyy').format(contact.createdAt),
            style: AppTextStyles.caption,
          ),
          onTap: activateContact,
        ),
      ],
    );
  }

  Widget _buildSourceBadge(String source) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppSpacing.borderRadiusPill,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Text(
        source,
        style: AppTextStyles.captionBold.copyWith(
          color: AppColors.textSecondary,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return switch (status) {
      'Thành công' => const AppBadge(
        label: 'Thành công',
        variant: AppBadgeVariant.success,
      ),
      'Đã gửi' => const AppBadge(
        label: 'Đã gửi',
        variant: AppBadgeVariant.info,
      ),
      'Thất bại' => const AppBadge(
        label: 'Thất bại',
        variant: AppBadgeVariant.error,
      ),
      _ => const AppBadge(label: 'Chưa gửi', variant: AppBadgeVariant.neutral),
    };
  }

  Future<void> _importDemoContacts(CustomersNotifier notifier) async {
    await notifier.importContacts(MockContacts.sampleContacts.take(5).toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã gửi loạt nhập khách hàng lên backend.')),
    );
  }

  Future<void> _showSaveSegmentDialog(CustomersNotifier notifier) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AppDialog(
          title: 'Lưu segment',
          subtitle:
              'Lưu bộ lọc hiện tại để dùng lại trong các lần chăm sóc sau.',
          icon: Icons.bookmark_add_outlined,
          actions: [
            AppDialogAction(
              text: 'Hủy',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            AppDialogAction(
              text: 'Lưu',
              icon: Icons.save_outlined,
              onPressed: () async {
                await notifier.saveCurrentFiltersAsSegment(
                  controller.text.trim(),
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
            ),
          ],
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Tên segment',
              border: OutlineInputBorder(),
            ),
          ),
        );
      },
    );
    controller.dispose();
  }

  Future<void> _showAddContactDialog(
    BuildContext context,
    CustomersNotifier notifier,
  ) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    String selectedGroup = 'Khách hàng VIP';
    String selectedTag = 'Bất động sản';
    bool submitting = false;

    final groups = [
      'Khách hàng VIP',
      'Khách hàng tiềm năng',
      'Đối tác',
      'Mặc định',
    ];
    final tags = [
      'Bất động sản',
      'Tài chính',
      'Công nghệ',
      'Giáo dục',
      'Thời trang',
      'Mặc định',
    ];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AppDialog(
              title: 'Thêm khách hàng mới',
              subtitle:
                  'Tạo khách hàng CRM thủ công để chăm sóc hoặc đưa vào chiến dịch.',
              icon: Icons.person_add_outlined,
              width: 560,
              showCloseButton: !submitting,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thông tin khách hàng',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  TextField(
                    controller: nameController,
                    enabled: !submitting,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên',
                      hintText: 'Nhập họ và tên khách hàng',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.s,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    enabled: !submitting,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                      hintText: 'Nhập số điện thoại Zalo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.s,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stackFields = constraints.maxWidth < 460;
                      final groupField = DropdownButtonFormField<String>(
                        initialValue: selectedGroup,
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(
                          labelText: 'Nhóm khách hàng',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.m,
                            vertical: AppSpacing.s,
                          ),
                        ),
                        items: groups.map((g) {
                          return DropdownMenuItem(value: g, child: Text(g));
                        }).toList(),
                        onChanged: submitting
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => selectedGroup = val);
                                }
                              },
                      );
                      final tagField = DropdownButtonFormField<String>(
                        initialValue: selectedTag,
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(
                          labelText: 'Lĩnh vực / Nhãn',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.m,
                            vertical: AppSpacing.s,
                          ),
                        ),
                        items: tags.map((t) {
                          return DropdownMenuItem(value: t, child: Text(t));
                        }).toList(),
                        onChanged: submitting
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => selectedTag = val);
                                }
                              },
                      );

                      if (stackFields) {
                        return Column(
                          children: [
                            groupField,
                            const SizedBox(height: AppSpacing.m),
                            tagField,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: groupField),
                          const SizedBox(width: AppSpacing.m),
                          Expanded(child: tagField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: AppSpacing.s,
                      runSpacing: AppSpacing.s,
                      children: [
                        AppButton(
                          text: 'Hủy',
                          variant: AppButtonVariant.outline,
                          onPressed: submitting
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                        ),
                        AppButton(
                          text: 'Thêm khách hàng',
                          isLoading: submitting,
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final phone = phoneController.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vui lòng nhập họ và tên.'),
                                ),
                              );
                              return;
                            }
                            if (phone.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vui lòng nhập số điện thoại.'),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              submitting = true;
                            });

                            final newContact = Contact(
                              id: '',
                              name: name,
                              phone: phone,
                              group: selectedGroup,
                              tag: selectedTag,
                              source: 'Thêm thủ công',
                              status: 'Chưa gửi',
                              createdAt: DateTime.now(),
                            );

                            final success = await notifier.addContact(
                              newContact,
                            );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Đã thêm khách hàng "$name" thành công.',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Lỗi khi thêm khách hàng hoặc gói cước đã hết hạn.',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    nameController.dispose();
    phoneController.dispose();
  }

  void _showPlaceholder(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
