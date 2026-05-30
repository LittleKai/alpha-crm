import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_shell_providers.dart';

class AppTopbar extends ConsumerWidget {
  final String currentRoute;
  final VoidCallback? onMenuPressed; // For opening drawer on mobile

  const AppTopbar({
    super.key,
    required this.currentRoute,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final breadcrumbs = _getBreadcrumbs(currentRoute);

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderSoft,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Row(
        children: [
          // Sidebar Toggle Button
          IconButton(
            icon: Icon(
              onMenuPressed != null
                  ? Icons.menu
                  : (isCollapsed ? Icons.menu_open : Icons.menu),
              color: AppColors.textSecondary,
            ),
            onPressed: onMenuPressed ??
                () {
                  ref.read(sidebarCollapsedProvider.notifier).state = !isCollapsed;
                },
          ),
          const SizedBox(width: AppSpacing.s),

          // Breadcrumbs
          Expanded(
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
                      if (!isLast)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs),
                          child: Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: AppColors.disabled,
                          ),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),

          // Right-side actions (user profile summary, etc.)
          _buildUserInfo(),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Row(
      children: [
        // Connected Indicator status placeholder
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.successSoft,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Zalo Connected',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.successText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        // User profile avatar placeholder
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primarySoft,
          child: Text(
            'AD',
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.primary,
            ),
          ),
        ),
      ],
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
    if (route.startsWith('/dashboard')) return ['Tổng quan'];
    if (route.startsWith('/customers')) return ['CRM', 'CRM Khách Hàng'];
    if (route.startsWith('/content/templates')) return ['CRM', 'Tin mẫu nhanh'];

    if (route.startsWith('/messaging/bulk')) return ['Chức năng nhắn tin', 'Gửi tin hàng loạt'];
    if (route.startsWith('/messaging/live-chat')) return ['Chức năng nhắn tin', 'Live Chat CRM Inbox'];
    if (route.startsWith('/messaging/chatbot')) return ['Chức năng nhắn tin', 'Chatbot Tự Động'];
    if (route.startsWith('/messaging/history')) return ['Chức năng nhắn tin', 'Lịch sử gửi tin'];

    if (route.startsWith('/friends/by-phone')) return ['Chức năng kết bạn', 'Kết bạn theo SĐT'];
    if (route.startsWith('/friends/by-group')) return ['Chức năng kết bạn', 'Kết bạn từ Nhóm Zalo'];
    if (route.startsWith('/friends/auto-approve')) return ['Chức năng kết bạn', 'Duyệt kết bạn tự động'];
    if (route.startsWith('/friends/history')) return ['Chức năng kết bạn', 'Lịch sử kết bạn'];

    if (route.startsWith('/groups/scan-members')) return ['Quản lý nhóm', 'Quét thành viên'];
    if (route.startsWith('/groups/join')) return ['Quản lý nhóm', 'Tham gia nhóm tự động'];
    if (route.startsWith('/groups/invite')) return ['Quản lý nhóm', 'Mời bạn bè vào nhóm'];
    if (route.startsWith('/groups/create')) return ['Quản lý nhóm', 'Tạo nhóm tự động'];
    if (route.startsWith('/groups/leave')) return ['Quản lý nhóm', 'Rời nhóm hàng loạt'];

    if (route.startsWith('/settings')) return ['Cài đặt hệ thống'];
    return ['Alpha CRM'];
  }
}
