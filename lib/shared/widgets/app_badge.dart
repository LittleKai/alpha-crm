import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

enum AppBadgeVariant { success, warning, error, info, neutral }

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textCol;

    switch (variant) {
      case AppBadgeVariant.success:
        bg = AppColors.successSoft;
        textCol = AppColors.successText;
        break;
      case AppBadgeVariant.info:
        bg = AppColors.infoSoft;
        textCol = AppColors.infoText;
        break;
      case AppBadgeVariant.warning:
        bg = AppColors.warningSoft;
        textCol = AppColors.warningText;
        break;
      case AppBadgeVariant.error:
        bg = AppColors.errorSoft;
        textCol = AppColors.errorText;
        break;
      case AppBadgeVariant.neutral:
        bg = AppColors.slateSoft;
        textCol = AppColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.borderRadiusPill,
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: textCol,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
