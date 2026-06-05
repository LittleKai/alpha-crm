import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

enum AppButtonVariant { primary, outline, destructive }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color textCol;
    BorderSide borderSide = BorderSide.none;

    if (isDisabled) {
      bg = isDark ? const Color(0xFF1E293B) : AppColors.disabled;
      textCol = isDark ? const Color(0xFF475569) : AppColors.disabledText;
    } else {
      switch (variant) {
        case AppButtonVariant.primary:
          bg = AppColors.primary;
          textCol = Colors.white;
          break;
        case AppButtonVariant.outline:
          bg = isDark ? const Color(0xFF111827) : AppColors.surface;
          textCol = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
          borderSide = BorderSide(
            color: isDark ? const Color(0xFF253247) : AppColors.border,
            width: 1,
          );
          break;
        case AppButtonVariant.destructive:
          bg = isDark ? const Color(0xFF3F0000) : AppColors.errorSoft;
          textCol = isDark ? const Color(0xFFF87171) : AppColors.errorText;
          borderSide = BorderSide(
            color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5),
            width: 1,
          );
          break;
      }
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: textCol,
      disabledBackgroundColor: bg,
      disabledForegroundColor: textCol,
      elevation: 0,
      minimumSize: Size(width ?? 80, height),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusS,
        side: borderSide,
      ),
    );

    Widget content;
    if (isLoading) {
      content = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == AppButtonVariant.primary
                ? Colors.white
                : AppColors.textSecondary,
          ),
        ),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: textCol),
            const SizedBox(width: AppSpacing.s),
          ],
          Text(
            text,
            style: AppTextStyles.label.copyWith(
              color: textCol,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        style: buttonStyle,
        onPressed: isDisabled ? null : onPressed,
        child: content,
      ),
    );
  }
}
