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
      child: isSegmented ? _buildSegmentedTabs() : _buildUnderlineTabs(),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.slateSoft,
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
                  color: isSelected ? AppColors.surface : Colors.transparent,
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
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
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

  Widget _buildUnderlineTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSoft, width: 1),
        ),
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
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (item.icon != null) ...[
          Icon(
            item.icon,
            size: iconSize,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
          SizedBox(width: iconGap),
        ],
        Text(item.label, style: textStyle),
      ],
    );
  }
}
