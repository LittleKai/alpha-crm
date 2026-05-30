import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

class AppSearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final VoidCallback? onClear;

  const AppSearchField({
    super.key,
    this.hintText = 'Tìm kiếm...',
    this.onChanged,
    this.controller,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AppColors.iconMuted,
          ),
          suffixIcon: controller != null && controller!.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    size: 16,
                    color: AppColors.iconMuted,
                  ),
                  onPressed: () {
                    controller!.clear();
                    if (onClear != null) onClear!();
                    if (onChanged != null) onChanged!('');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: AppSpacing.sm,
          ),
        ),
      ),
    );
  }
}
