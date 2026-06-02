import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../mock/mock_campaigns.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_badge.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/app_empty_state.dart';
import '../../../../../shared/widgets/app_metric_card.dart';
import '../../../../../shared/widgets/app_search_field.dart';
import '../../../../../shared/widgets/app_select_field.dart';
import '../../../../../shared/widgets/app_table.dart';
import '../../providers/send_history_provider.dart';

class SendHistoryScreen extends ConsumerStatefulWidget {
  const SendHistoryScreen({super.key});

  @override
  ConsumerState<SendHistoryScreen> createState() => _SendHistoryScreenState();
}

class _SendHistoryScreenState extends ConsumerState<SendHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sendHistoryProvider);
    final notifier = ref.read(sendHistoryProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final filteredRecords = _getFilteredRecords(state);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.l),
            _buildMetricsGrid(state),
            const SizedBox(height: AppSpacing.l),
            _buildToolbar(state, notifier),
            const SizedBox(height: AppSpacing.l),
            _buildTableCard(state, filteredRecords),
          ],
        ),
      ),
    );
  }

  List<SendHistoryRecord> _getFilteredRecords(SendHistoryState state) {
    return state.records.where((record) {
      final query = state.searchQuery.toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          record.campaignName.toLowerCase().contains(query) ||
          record.phone.contains(query) ||
          record.message.toLowerCase().contains(query);

      final matchesStatus =
          state.selectedStatus == 'Tất cả' ||
          record.status == state.selectedStatus;

      return matchesQuery && matchesStatus;
    }).toList();
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.history_outlined, color: AppColors.primary, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lịch sử gửi tin', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Lịch sử chi tiết tất cả tin nhắn đã gửi từ hệ thống',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(SendHistoryState state) {
    final total = state.records.length;
    final success = state.records.where((r) => r.status == 'Thành công').length;
    final failure = state.records.where((r) => r.status == 'Thất bại').length;
    final pending = state.records.where((r) => r.status == 'Đang chờ').length;

    final cards = [
      AppMetricCard(
        title: 'Tổng gửi',
        value: total.toString(),
        icon: Icons.send_rounded,
        iconColor: AppColors.primary,
        iconBackgroundColor: AppColors.primarySoft,
      ),
      AppMetricCard(
        title: 'Thành công',
        value: success.toString(),
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.success,
        iconBackgroundColor: AppColors.successSoft,
      ),
      AppMetricCard(
        title: 'Thất bại',
        value: failure.toString(),
        icon: Icons.cancel_outlined,
        iconColor: AppColors.error,
        iconBackgroundColor: AppColors.errorSoft,
      ),
      AppMetricCard(
        title: 'Đang chờ',
        value: pending.toString(),
        icon: Icons.hourglass_empty_rounded,
        iconColor: AppColors.warning,
        iconBackgroundColor: AppColors.warningSoft,
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

  Widget _buildToolbar(SendHistoryState state, SendHistoryNotifier notifier) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final statusList = ['Tất cả', 'Thành công', 'Thất bại', 'Đang chờ'];

    final search = AppSearchField(
      hintText: 'Tìm kiếm theo chiến dịch, tên, SĐT, nội dung...',
      controller: _searchController,
      onChanged: notifier.setSearchQuery,
    );

    final filter = AppSelectField<String>(
      value: state.selectedStatus,
      items: statusList
          .map((status) => DropdownMenuItem(value: status, child: Text(status)))
          .toList(),
      onChanged: (val) {
        if (val != null) notifier.setSelectedStatus(val);
      },
    );

    final actions = [
      AppButton(
        text: 'Làm mới',
        icon: Icons.refresh,
        variant: AppButtonVariant.outline,
        onPressed: notifier.loadRecords,
      ),
      AppButton(
        text: 'Xuất Excel',
        icon: Icons.download_outlined,
        variant: AppButtonVariant.outline,
        onPressed: state.records.isEmpty
            ? null
            : () async {
                final exported = await notifier.exportToCsv();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      exported
                          ? 'Đã copy dữ liệu CSV vào Clipboard! Bạn có thể dán vào Excel.'
                          : 'Không thể export CSV từ dữ liệu hiện tại.',
                    ),
                  ),
                );
              },
      ),
    ];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: AppSpacing.s),
          filter,
          const SizedBox(height: AppSpacing.s),
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
        Expanded(flex: 3, child: search),
        const SizedBox(width: AppSpacing.s),
        SizedBox(width: 160, child: filter),
        const SizedBox(width: AppSpacing.s),
        Wrap(spacing: AppSpacing.s, children: actions),
      ],
    );
  }

  Widget _buildTableCard(
    SendHistoryState state,
    List<SendHistoryRecord> filteredRecords,
  ) {
    if (state.records.isEmpty) {
      return AppCard(
        child: AppEmptyState(
          icon: Icons.history_outlined,
          title: 'Không tìm thấy dữ liệu',
          description:
              'Hệ thống chưa ghi nhận lượt gửi tin nhắn nào từ các chiến dịch.',
          height: 350,
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 400,
        child: AppTable(
          isEmpty: filteredRecords.isEmpty,
          emptyTitle: 'Không tìm thấy lịch sử phù hợp',
          emptyDescription:
              'Hãy thử tìm kiếm với từ khóa khác hoặc đổi bộ lọc trạng thái.',
          columns: const [
            AppTableColumn(label: 'Tên chiến dịch', size: ColumnSize.M),
            AppTableColumn(label: 'SĐT Nhận', size: ColumnSize.S),
            AppTableColumn(label: 'Nội dung tin nhắn', size: ColumnSize.L),
            AppTableColumn(label: 'Trạng thái', size: ColumnSize.S),
            AppTableColumn(label: 'Thời gian', size: ColumnSize.S),
          ],
          rows: filteredRecords.map((record) {
            return DataRow(
              cells: [
                DataCell(
                  Text(record.campaignName, style: AppTextStyles.bodyMedium),
                ),
                DataCell(Text(record.phone, style: AppTextStyles.body)),
                DataCell(
                  Tooltip(
                    message: record.message,
                    child: Text(
                      record.message,
                      style: AppTextStyles.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(_buildStatusBadge(record.status)),
                DataCell(
                  Text(
                    DateFormat('dd/MM HH:mm').format(record.sentAt),
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return switch (status) {
      'Thành công' => const AppBadge(
        label: 'Thành công',
        variant: AppBadgeVariant.success,
      ),
      'Thất bại' => const AppBadge(
        label: 'Thất bại',
        variant: AppBadgeVariant.error,
      ),
      'Đang chờ' => const AppBadge(
        label: 'Đang chờ',
        variant: AppBadgeVariant.warning,
      ),
      _ => const AppBadge(label: 'Không rõ', variant: AppBadgeVariant.neutral),
    };
  }
}
