import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';

class CustomersScreenPlaceholder extends StatelessWidget {
  const CustomersScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CRM Khách Hàng',
            style: AppTextStyles.pageTitle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Quản lý danh sách, phân loại và liên hệ khách hàng Zalo',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.l),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.contact_phone_outlined,
                      size: 64,
                      color: AppColors.iconMuted.withOpacity(0.5),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Text(
                      'Màn hình Khách hàng',
                      style: AppTextStyles.sectionTitle,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      'Nội dung quản lý liên hệ đang được phát triển bởi AGENT-06.',
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
