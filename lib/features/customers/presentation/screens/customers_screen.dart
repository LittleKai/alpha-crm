import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../mock/mock_contacts.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
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

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();

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

    return Scaffold(
      backgroundColor: AppColors.appBackground,
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
            _buildToolbar(state, notifier),
            const SizedBox(height: AppSpacing.l),
            _buildMainContent(state, filteredContacts, isEmpty),
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
      const AppMetricCard(
        title: 'Khách hàng tiềm năng',
        value: '0',
        icon: Icons.group_outlined,
        iconColor: AppColors.warning,
        iconBackgroundColor: AppColors.warningSoft,
      ),
      const AppMetricCard(
        title: 'Khách hàng VIP',
        value: '0',
        icon: Icons.group_outlined,
        iconColor: Color(0xFFA855F7),
        iconBackgroundColor: AppColors.purpleSoft,
      ),
      const AppMetricCard(
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

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: AppSpacing.s),
          ...filters.map(
            (filter) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: filter,
            ),
          ),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: actions,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 4, child: search),
        const SizedBox(width: AppSpacing.s),
        ...filters.map(
          (filter) => Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s),
            child: SizedBox(width: 150, child: filter),
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: actions,
        ),
      ],
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
              onPressed: () => _showAddContactDialog(context, ref.read(customersProvider.notifier)),
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
          rows: filteredContacts.map(_buildContactRow).toList(),
        ),
      ),
    );
  }

  DataRow _buildContactRow(Contact contact) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            contact.name,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        DataCell(Text(contact.phone, style: AppTextStyles.body)),
        DataCell(Text(contact.group, style: AppTextStyles.body)),
        DataCell(Text(contact.tag, style: AppTextStyles.body)),
        DataCell(Text(contact.source, style: AppTextStyles.body)),
        DataCell(_buildStatusBadge(contact.status)),
        DataCell(
          Text(
            DateFormat('dd/MM/yyyy').format(contact.createdAt),
            style: AppTextStyles.caption,
          ),
        ),
      ],
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
        return AlertDialog(
          title: const Text('Lưu segment'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Tên segment',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                await notifier.saveCurrentFiltersAsSegment(
                  controller.text.trim(),
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Lưu'),
            ),
          ],
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
    
    final groups = ['Khách hàng VIP', 'Khách hàng tiềm năng', 'Đối tác', 'Mặc định'];
    final tags = ['Bất động sản', 'Tài chính', 'Công nghệ', 'Giáo dục', 'Thời trang', 'Mặc định'];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              title: const Row(
                children: [
                  Icon(Icons.person_add_outlined, color: AppColors.primary, size: 28),
                  SizedBox(width: AppSpacing.s),
                  Text(
                    'Thêm khách hàng mới',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
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
                        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedGroup,
                            dropdownColor: AppColors.surface,
                            decoration: const InputDecoration(
                              labelText: 'Nhóm khách hàng',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
                            ),
                            items: groups.map((g) {
                              return DropdownMenuItem(value: g, child: Text(g));
                            }).toList(),
                            onChanged: submitting ? null : (val) {
                              if (val != null) {
                                setState(() {
                                  selectedGroup = val;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedTag,
                            dropdownColor: AppColors.surface,
                            decoration: const InputDecoration(
                              labelText: 'Lĩnh vực / Nhãn',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
                            ),
                            items: tags.map((t) {
                              return DropdownMenuItem(value: t, child: Text(t));
                            }).toList(),
                            onChanged: submitting ? null : (val) {
                              if (val != null) {
                                setState(() {
                                  selectedTag = val;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.only(
                left: AppSpacing.l,
                right: AppSpacing.l,
                bottom: AppSpacing.l,
              ),
              actions: [
                AppButton(
                  text: 'Hủy',
                  variant: AppButtonVariant.outline,
                  onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(),
                ),
                const SizedBox(width: AppSpacing.xs),
                AppButton(
                  text: 'Thêm khách hàng',
                  isLoading: submitting,
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập họ và tên.')),
                      );
                      return;
                    }
                    if (phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập số điện thoại.')),
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
                    
                    final success = await notifier.addContact(newContact);
                    
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Đã thêm khách hàng "$name" thành công.')),
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
                                Icon(Icons.error_outline, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Lỗi khi thêm khách hàng hoặc gói cước đã hết hạn.')),
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
            );
          }
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
