import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

class AppSelectField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final String? labelText;

  const AppSelectField({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.hintText,
    this.labelText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimaryColor = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.textPrimary;
    final textSecondaryColor = isDark
        ? const Color(0xFF94A3B8)
        : AppColors.textSecondary;
    final textMutedColor = isDark
        ? const Color(0xFF64748B)
        : AppColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: AppTextStyles.label.copyWith(color: textPrimaryColor),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        SizedBox(
          height: 45,
          child: DropdownButtonFormField<T>(
            // Guard against the Flutter assertion that requires exactly one item
            // matching `value`. If the current value is missing/duplicated in the
            // items (e.g. list reloaded with new instances), fall back to null.
            value:
                (value != null &&
                    items.where((item) => item.value == value).length == 1)
                ? value
                : null,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            style: AppTextStyles.body,
            icon: Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: textSecondaryColor,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: AppTextStyles.body.copyWith(color: textMutedColor),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: 8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
