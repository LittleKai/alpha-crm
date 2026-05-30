import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

enum AppAlertVariant { success, info, warning, error }

class AppAlert extends StatelessWidget {
  final String message;
  final String? title;
  final AppAlertVariant variant;
  final IconData? customIcon;

  const AppAlert({
    super.key,
    required this.message,
    this.title,
    this.variant = AppAlertVariant.info,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color borderCol;
    Color textCol;
    IconData icon;

    switch (variant) {
      case AppAlertVariant.success:
        bg = AppColors.successSoft;
        borderCol = const Color(0xFFD1FAE5);
        textCol = AppColors.successText;
        icon = customIcon ?? Icons.check_circle_outline;
        break;
      case AppAlertVariant.info:
        bg = AppColors.infoSoft;
        borderCol = const Color(0xFFBFD2FF);
        textCol = AppColors.infoText;
        icon = customIcon ?? Icons.info_outline;
        break;
      case AppAlertVariant.warning:
        bg = AppColors.warningSoft;
        borderCol = const Color(0xFFFDE68A);
        textCol = AppColors.warningText;
        icon = customIcon ?? Icons.warning_amber_outlined;
        break;
      case AppAlertVariant.error:
        bg = AppColors.errorSoft;
        borderCol = const Color(0xFFFCA5A5);
        textCol = AppColors.errorText;
        icon = customIcon ?? Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textCol, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: textCol,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Text(
                  message,
                  style: AppTextStyles.body.copyWith(
                    color: textCol,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
