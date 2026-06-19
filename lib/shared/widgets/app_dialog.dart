import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import 'app_button.dart';

class AppDialogAction {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  const AppDialogAction({
    required this.text,
    this.icon,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
  });
}

class AppDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final List<AppDialogAction> actions;
  final double width;
  final bool showCloseButton;

  const AppDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.width = 560,
    this.showCloseButton = true,
  });

  @override
  @override
  Widget build(BuildContext context) {
    final dialogWidth = MediaQuery.sizeOf(context).width < width + 48
        ? MediaQuery.sizeOf(context).width - 32
        : width;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.l,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusM),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: 820),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppDialogHeader(
              title: title,
              subtitle: subtitle,
              icon: icon,
              showCloseButton: showCloseButton,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.m,
                  AppSpacing.l,
                  AppSpacing.l,
                ),
                child: child,
              ),
            ),
            if (actions.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.m,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.borderSoft,
                      width: 1,
                    ),
                  ),
                ),
                child: Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  alignment: WrapAlignment.end,
                  children: actions.map((action) {
                    return AppButton(
                      text: action.text,
                      icon: action.icon,
                      variant: action.variant,
                      onPressed: action.onPressed,
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppDialogSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final String? description;

  const AppDialogSection({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceMuted = isDark
        ? const Color(0xFF162033)
        : AppColors.surfaceMuted;
    final border = isDark ? const Color(0xFF253247) : AppColors.border;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: surfaceMuted,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.s),
            Text(
              description!,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTextStyles.body.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppDialogHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool showCloseButton;

  const _AppDialogHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.showCloseButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.m,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showCloseButton)
            IconButton(
              tooltip: 'Đóng',
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}
