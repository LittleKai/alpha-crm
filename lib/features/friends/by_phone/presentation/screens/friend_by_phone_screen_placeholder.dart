import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';

class FriendByPhoneScreenPlaceholder extends StatelessWidget {
  const FriendByPhoneScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kết bạn theo SĐT',
            style: AppTextStyles.pageTitle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tự động gửi lời mời kết bạn hàng loạt theo danh sách số điện thoại',
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
                      'Màn hình Kết bạn theo SĐT',
                      style: AppTextStyles.sectionTitle,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      'Nội dung import SĐT và cấu hình kết bạn đang được phát triển bởi AGENT-12.',
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
