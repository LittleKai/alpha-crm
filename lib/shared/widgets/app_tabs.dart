import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

class AppTabItem {
  final String label;
  final IconData? icon;

  const AppTabItem({required this.label, this.icon});
}

class AppTabs extends StatelessWidget {
  final List<AppTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final bool isSegmented;

  const AppTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.isSegmented = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: isSegmented
          ? _buildSegmentedTabs(context)
          : _buildUnderlineTabs(context),
    );
  }

  Widget _buildSegmentedTabs(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final slateSoftColor = isDark
        ? const Color(0xFF1E293B)
        : AppColors.slateSoft;
    final surfaceColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final textSecondaryColor = isDark
        ? const Color(0xFF94A3B8)
        : AppColors.textSecondary;

    return Container(
      height: 40,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: slateSoftColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(tabs.length, (index) {
          final isSelected = selectedIndex == index;
          final item = tabs[index];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: InkWell(
              onTap: () => onTabSelected(index),
              borderRadius: BorderRadius.circular(AppSpacing.radiusS - 2),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                decoration: BoxDecoration(
                  color: isSelected ? surfaceColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusS - 2),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color.fromRGBO(15, 23, 42, 0.04),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: _TabContent(
                  item: item,
                  isSelected: isSelected,
                  iconSize: 14,
                  iconGap: AppSpacing.xs,
                  textStyle: AppTextStyles.label.copyWith(
                    color: isSelected ? AppColors.primary : textSecondaryColor,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildUnderlineTabs(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderSoftColor = theme.dividerTheme.color ?? theme.dividerColor;
    final textSecondaryColor = isDark
        ? const Color(0xFF94A3B8)
        : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderSoftColor, width: 1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(tabs.length, (index) {
          final isSelected = selectedIndex == index;
          final item = tabs[index];

          return InkWell(
            onTap: () => onTabSelected(index),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: _TabContent(
                item: item,
                isSelected: isSelected,
                iconSize: 16,
                iconGap: AppSpacing.s,
                textStyle: AppTextStyles.bodyMedium.copyWith(
                  color: isSelected ? AppColors.primary : textSecondaryColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  final AppTabItem item;
  final bool isSelected;
  final double iconSize;
  final double iconGap;
  final TextStyle textStyle;

  const _TabContent({
    required this.item,
    required this.isSelected,
    required this.iconSize,
    required this.iconGap,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondaryColor = isDark
        ? const Color(0xFF94A3B8)
        : AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (item.icon != null) ...[
          Icon(
            item.icon,
            size: iconSize,
            color: isSelected ? AppColors.primary : textSecondaryColor,
          ),
          SizedBox(width: iconGap),
        ],
        Text(item.label, style: textStyle),
      ],
    );
  }
}
