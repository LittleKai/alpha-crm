import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/app_empty_state.dart';

class FriendHistoryScreenPlaceholder extends StatelessWidget {
  const FriendHistoryScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            const SizedBox(height: AppSpacing.l),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  _CardTitle(),
                  Divider(height: 1, color: AppColors.borderSoft),
                  AppEmptyState(
                    icon: Icons.access_time_rounded,
                    title: 'Chưa có lịch sử kết bạn nào',
                    description:
                        'Khi bạn khởi động chiến dịch, kết quả chi tiết sẽ được ghi nhận tại đây.',
                    height: 280,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.access_time_outlined,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lịch sử chiến dịch kết bạn',
                style: AppTextStyles.pageTitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Quản lý lịch sử và nhật ký trạng thái chi tiết của các chiến dịch.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        children: [
          const Icon(
            Icons.access_time_outlined,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.s),
          Text('Lịch sử kết bạn', style: AppTextStyles.sectionTitle),
        ],
      ),
    );
  }
}
