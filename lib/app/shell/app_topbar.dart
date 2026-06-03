import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../../shared/widgets/compliance_warnings_popup.dart';

class AppTopbar extends ConsumerWidget {
  final String currentRoute;
  final VoidCallback? onMenuPressed;

  const AppTopbar({super.key, required this.currentRoute, this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breadcrumbs = _getBreadcrumbs(currentRoute);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSoft, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (onMenuPressed != null) ...[
            IconButton(
              tooltip: 'Mở menu',
              icon: const Icon(Icons.menu, color: AppColors.textSecondary),
              onPressed: onMenuPressed,
            ),
            const SizedBox(width: AppSpacing.s),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Icon(
                    _getRouteIcon(currentRoute),
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  ...List.generate(breadcrumbs.length, (index) {
                    final isLast = index == breadcrumbs.length - 1;
                    return Row(
                      children: [
                        Text(
                          breadcrumbs[index],
                          style: isLast
                              ? AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                )
                              : AppTextStyles.body.copyWith(
                                  color: AppColors.textMuted,
                                ),
                        ),
                        if (!isLast) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: AppColors.disabled,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          const WarningIconButton(),
        ],
      ),
    );
  }

  IconData _getRouteIcon(String route) {
    if (route.startsWith('/dashboard')) return Icons.dashboard_outlined;
    if (route.startsWith('/customers')) return Icons.people_outline;
    if (route.startsWith('/content')) return Icons.quickreply_outlined;
    if (route.startsWith('/messaging')) return Icons.send_outlined;
    if (route.startsWith('/friends')) return Icons.person_add_alt_outlined;
    if (route.startsWith('/groups')) return Icons.group_outlined;
    if (route.startsWith('/settings')) return Icons.settings_outlined;
    return Icons.link;
  }

  List<String> _getBreadcrumbs(String route) {
    if (route.startsWith('/dashboard')) {
      return ['Tổng quan'];
    }
    if (route.startsWith('/customers')) {
      return ['CRM Zalo', 'Khách hàng', 'CRM Khách hàng'];
    }
    if (route.startsWith('/content/templates')) {
      return ['CRM Zalo', 'Chiến dịch', 'Tin nhắn mẫu'];
    }
    if (route.startsWith('/messaging/bulk')) {
      return ['Chức năng nhắn tin', 'Gửi tin hàng loạt'];
    }
    if (route.startsWith('/messaging/live-chat')) {
      return ['Chức năng nhắn tin', 'Live Chat CRM Inbox'];
    }
    if (route.startsWith('/messaging/chatbot')) {
      return ['Chức năng nhắn tin', 'Chatbot Tự Động'];
    }
    if (route.startsWith('/messaging/history')) {
      return ['Chức năng nhắn tin', 'Lịch sử gửi tin'];
    }
    if (route.startsWith('/friends/by-phone')) {
      return ['Chức năng kết bạn', 'Kết bạn theo SĐT'];
    }
    if (route.startsWith('/friends/by-group')) {
      return ['Chức năng kết bạn', 'Kết bạn từ Nhóm Zalo'];
    }
    if (route.startsWith('/friends/auto-approve')) {
      return ['Chức năng kết bạn', 'Duyệt kết bạn tự động'];
    }
    if (route.startsWith('/friends/history')) {
      return ['Chức năng kết bạn', 'Lịch sử kết bạn'];
    }
    if (route.startsWith('/groups/scan-members')) {
      return ['Quản lý nhóm', 'Quét thành viên'];
    }
    if (route.startsWith('/groups/join')) {
      return ['Quản lý nhóm', 'Tham gia nhóm tự động'];
    }
    if (route.startsWith('/groups/invite')) {
      return ['Quản lý nhóm', 'Mời bạn bè vào nhóm'];
    }
    if (route.startsWith('/groups/create')) {
      return ['Quản lý nhóm', 'Tạo nhóm tự động'];
    }
    if (route.startsWith('/groups/leave')) {
      return ['Quản lý nhóm', 'Rời nhóm hàng loạt'];
    }
    if (route.startsWith('/settings')) {
      return ['Cài đặt hệ thống'];
    }
    return ['Alpha CRM'];
  }
}
