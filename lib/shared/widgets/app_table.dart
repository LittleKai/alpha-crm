import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import 'app_empty_state.dart';

class AppTableColumn {
  final String label;
  final ColumnSize size;
  final bool numeric;

  const AppTableColumn({
    required this.label,
    this.size = ColumnSize.M,
    this.numeric = false,
  });
}

class AppTable extends StatelessWidget {
  final List<AppTableColumn> columns;
  final List<DataRow> rows;
  final bool isLoading;
  final bool isEmpty;
  final bool isError;
  final String? errorMessage;
  final String emptyTitle;
  final String emptyDescription;
  final IconData emptyIcon;

  const AppTable({
    super.key,
    required this.columns,
    required this.rows,
    this.isLoading = false,
    this.isEmpty = false,
    this.isError = false,
    this.errorMessage,
    this.emptyTitle = 'Không có dữ liệu',
    this.emptyDescription = 'Hiện tại chưa có bản ghi nào được lưu trong hệ thống.',
    this.emptyIcon = Icons.folder_open_outlined,
  });

  @override
  Widget build(BuildContext context) {
    if (isError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.errorText, size: 48),
              const SizedBox(height: AppSpacing.m),
              Text(
                'Đã xảy ra lỗi khi tải dữ liệu',
                style: AppTextStyles.sectionTitle.copyWith(color: AppColors.errorText),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.s),
                Text(
                  errorMessage!,
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (isEmpty && !isLoading) {
      return AppEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        description: emptyDescription,
      );
    }

    return Stack(
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            cardColor: AppColors.surface,
            dividerColor: AppColors.borderSoft,
          ),
          child: DataTable2(
            columnSpacing: AppSpacing.m,
            horizontalMargin: AppSpacing.m,
            minWidth: 600,
            headingRowHeight: 48,
            dataRowHeight: 48,
            headingRowColor: WidgetStateProperty.all(AppColors.surfaceMuted),
            headingTextStyle: AppTextStyles.label.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            columns: columns.map((col) {
              return DataColumn2(
                label: Text(col.label),
                size: col.size,
                numeric: col.numeric,
              );
            }).toList(),
            rows: isLoading ? [] : rows,
          ),
        ),
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.6),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
