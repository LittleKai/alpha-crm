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
  final TextAlign? textAlign;

  const AppTableColumn({
    required this.label,
    this.size = ColumnSize.M,
    this.numeric = false,
    this.textAlign,
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
    this.emptyDescription =
        'Hiện tại chưa có bản ghi nào được lưu trong hệ thống.',
    this.emptyIcon = Icons.folder_open_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final errorColor = isDark ? const Color(0xFFF87171) : AppColors.errorText;
    final textSecondaryColor = isDark
        ? Colors.white
        : AppColors.textSecondary;
    final surfaceColor = isDark ? const Color(0xFF111827) : AppColors.surface;
    final borderSoftColor = isDark
        ? const Color(0xFF1E293B)
        : AppColors.borderSoft;
    final surfaceMutedColor = isDark
        ? const Color(0xFF162033)
        : AppColors.surfaceMuted;
    final textPrimaryColor = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.textPrimary;
    final overlayColor = isDark
        ? Colors.black.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.6);

    if (isError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: errorColor, size: 48),
              const SizedBox(height: AppSpacing.m),
              Text(
                'Đã xảy ra lỗi khi tải dữ liệu',
                style: AppTextStyles.sectionTitle.copyWith(color: errorColor),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.s),
                Text(
                  errorMessage!,
                  style: AppTextStyles.body.copyWith(color: textSecondaryColor),
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
          data: theme.copyWith(
            cardColor: surfaceColor,
            dividerColor: borderSoftColor,
          ),
          child: DataTable2(
            columnSpacing: AppSpacing.m,
            horizontalMargin: AppSpacing.m,
            minWidth: 600,
            headingRowHeight: 48,
            dataRowHeight: 48,
            headingRowColor: WidgetStateProperty.all(surfaceMutedColor),
            headingTextStyle: AppTextStyles.label.copyWith(
              color: textPrimaryColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            columns: columns.map((col) {
              Widget labelWidget = Text(col.label, textAlign: col.textAlign);
              if (col.textAlign == TextAlign.center) {
                labelWidget = Center(child: labelWidget);
              }
              return DataColumn2(
                label: labelWidget,
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
              color: overlayColor,
              child: Center(
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
