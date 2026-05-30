import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../providers/live_chat_provider.dart';

class LiveChatScreen extends ConsumerWidget {
  const LiveChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveChatProvider);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              isMobile: isMobile,
              isLoading: state.isLoading,
              onRefresh: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chưa có tài khoản để tải lại.'),
                  ),
                );
              },
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 58,
                        color: AppColors.iconMuted.withValues(alpha: 0.9),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      Text(
                        'Không có tài khoản Zalo kết nối',
                        style: AppTextStyles.sectionTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        'Vui lòng di chuyển tới mục Cài đặt để quét mã QR và đăng nhập tài khoản Zalo trước khi sử dụng Live Chat.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isMobile;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _Header({
    required this.isMobile,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final title = Row(
      children: [
        const Icon(
          Icons.chat_bubble_outline,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Live Chat (CRM Inbox)', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Hộp thư tập trung đa tài khoản Zalo. Tích hợp đồng bộ CRM thời gian thực.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'TÀI KHOẢN:',
          style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.s),
        const _DisconnectedSelect(),
        const SizedBox(width: AppSpacing.s),
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            onPressed: isLoading ? null : onRefresh,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh, size: 18),
          ),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: AppSpacing.m),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: controls,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: title),
        controls,
      ],
    );
  }
}

class _DisconnectedSelect extends StatelessWidget {
  const _DisconnectedSelect();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.borderRadiusS,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Chưa kết nối tài khoản nào',
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
