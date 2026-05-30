import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Widget>? actions;
  final double height;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actions,
    this.height = 280.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppSpacing.l),
      alignment: Alignment.center,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Icon(
              icon,
              size: 56,
              color: AppColors.iconMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.m),
            // Title
            Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s),
            // Description
            Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                description,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.l),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.s,
                alignment: WrapAlignment.center,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
