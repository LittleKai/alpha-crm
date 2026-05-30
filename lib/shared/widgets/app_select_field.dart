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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        SizedBox(
          height: 40,
          child: DropdownButtonFormField<T>(
            initialValue: value,
            items: items,
            onChanged: onChanged,
            style: AppTextStyles.body,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AppColors.textSecondary,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: AppTextStyles.body.copyWith(
                color: AppColors.textMuted,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
