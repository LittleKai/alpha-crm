import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

class AppSelectField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final DropdownButtonBuilder? selectedItemBuilder;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final String? labelText;
  final String? helperText;
  final double? itemHeight;

  const AppSelectField({
    super.key,
    required this.items,
    this.selectedItemBuilder,
    this.value,
    this.onChanged,
    this.hintText,
    this.labelText,
    this.helperText,
    this.itemHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimaryColor = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.textPrimary;
    final textSecondaryColor = isDark
        ? Colors.white
        : AppColors.textSecondary;
    final textMutedColor = isDark
        ? Colors.white60
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
          height: 42,
          child: DropdownButtonFormField<T>(
            value:
                (value != null &&
                    items.where((item) => item.value == value).length == 1)
                ? value
                : null,
            items: items,
            selectedItemBuilder: selectedItemBuilder,
            onChanged: onChanged,
            isExpanded: true,
            itemHeight: itemHeight,
            style: AppTextStyles.body.copyWith(color: textPrimaryColor),
            icon: Icon(
              Icons.unfold_more_rounded,
              size: 20,
              color: textSecondaryColor,
            ),
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            elevation: 4,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: AppTextStyles.body.copyWith(color: textMutedColor),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: 0,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              hoverColor: Colors.transparent,
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: AppTextStyles.caption.copyWith(
              color: textMutedColor,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
