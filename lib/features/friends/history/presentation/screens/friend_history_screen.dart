import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/app_empty_state.dart';
import '../../../../../shared/widgets/app_search_field.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../providers/friend_history_provider.dart';

class FriendHistoryScreen extends ConsumerStatefulWidget {
  const FriendHistoryScreen({super.key});

  @override
  ConsumerState<FriendHistoryScreen> createState() =>
      _FriendHistoryScreenState();
}

class _FriendHistoryScreenState extends ConsumerState<FriendHistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendHistoryProvider);
    final notifier = ref.read(friendHistoryProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final filteredRecords = state.records.where((r) {
      if (_searchQuery.isEmpty) return true;
      return r.targetName.toLowerCase().contains(_searchQuery) ||
          r.targetPhone.contains(_searchQuery) ||
          r.accountLabel.toLowerCase().contains(_searchQuery);
    }).toList();

    final totalCount = state.records.length;
    final successCount = state.records
        .where((r) => r.status == 'Thành công')
        .length;
    final failedCount = state.records
        .where((r) => r.status == 'Thất bại')
        .length;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.m),
            _buildMetricsGrid(totalCount, successCount, failedCount, isMobile),
            const SizedBox(height: AppSpacing.m),
            _buildToolbar(notifier, state.records.isNotEmpty),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: AppCard(
                padding: EdgeInsets.zero,
                child: state.records.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.access_time_rounded,
                        title: 'Chưa có lịch sử kết bạn nào',
                        description:
                            'Khi bạn chạy chiến dịch kết bạn theo SĐT hoặc kết bạn từ nhóm, nhật ký chi tiết sẽ hiển thị tại đây.',
                        height: 320,
                      )
                    : filteredRecords.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'Không tìm thấy kết quả phù hợp.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    : _buildHistoryTable(filteredRecords),
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
        const Icon(
          Icons.access_time_outlined,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lịch sử chiến dịch kết bạn',
                style: AppTextStyles.pageTitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Theo dõi và quản lý lịch sử chi tiết của tất cả chiến dịch gửi lời mời kết bạn.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(int total, int success, int failed, bool isMobile) {
    final widgets = [
      _buildMetricCard(
        'Tổng số yêu cầu gửi',
        total.toString(),
        AppColors.primary,
      ),
      _buildMetricCard('Gửi thành công', success.toString(), AppColors.success),
      _buildMetricCard('Gửi thất bại', failed.toString(), AppColors.error),
    ];

    if (isMobile) {
      return Column(
        children: widgets
            .map(
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: w,
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: widgets
          .map(
            (w) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: w,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.borderRadiusM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.pageTitle.copyWith(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(FriendHistoryNotifier notifier, bool hasRecords) {
    return Row(
      children: [
        Expanded(
          child: AppSearchField(
            controller: _searchController,
            hintText: 'Tìm kiếm theo tên hoặc SĐT...',
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        AppButton(
          text: 'Xóa lịch sử',
          icon: Icons.delete_outline_rounded,
          variant: AppButtonVariant.outline,
          onPressed: hasRecords ? notifier.clearHistory : null,
        ),
      ],
    );
  }

  Widget _buildHistoryTable(List<FriendHistoryRecord> records) {
    return ListView.separated(
      itemCount: records.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: AppColors.borderSoft),
      itemBuilder: (context, index) {
        final record = records[index];
        final isSuccess = record.status == 'Thành công';

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.targetName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.targetPhone,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.accountLabel, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      record.timestamp,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  record.message,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? AppColors.successSoft
                      : AppColors.errorSoft,
                  borderRadius: AppSpacing.borderRadiusS,
                ),
                child: Text(
                  record.status,
                  style: AppTextStyles.caption.copyWith(
                    color: isSuccess ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
