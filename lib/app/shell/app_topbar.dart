import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_tokens.dart';
import '../routing/app_routes.dart';
import 'app_shell_providers.dart';
import 'command_palette_dialog.dart';
import '../../shared/widgets/compliance_warnings_popup.dart';
import '../../shared/widgets/app_dialog.dart';

import '../../features/auth/providers/crm_auth_provider.dart';
import '../../features/messaging/bulk/providers/bulk_messaging_provider.dart';
import '../../features/messaging/live_chat/providers/live_chat_provider.dart';
import '../../features/tasks/providers/crm_tasks_provider.dart';
import '../../features/zalo_integration/providers/zalo_integration_provider.dart';

class AppTopbar extends ConsumerStatefulWidget {
  final String currentRoute;
  final VoidCallback? onMenuPressed;

  const AppTopbar({super.key, required this.currentRoute, this.onMenuPressed});

  @override
  ConsumerState<AppTopbar> createState() => _AppTopbarState();
}

class _AppTopbarState extends ConsumerState<AppTopbar> {
  @override
  Widget build(BuildContext context) {
    final breadcrumbs = _getBreadcrumbs(widget.currentRoute);

    final zaloState = ref.watch(zaloIntegrationProvider);
    final authState = ref.watch(crmAuthProvider);

    int notifCount = 0;
    if (!zaloState.isBackendActive) notifCount++;
    for (final acc in zaloState.accounts) {
      if (!acc.connected || !acc.listenerRunning) notifCount++;
    }
    if (zaloState.agentError != null) notifCount++;
    final subscriptionStatus = authState.subscriptionStatus;
    final hasKnownSubscriptionWarning =
        authState.isAuthenticated &&
        subscriptionStatus != null &&
        subscriptionStatus != 'active';
    if (hasKnownSubscriptionWarning) notifCount++;

    final tokens = AppThemeTokens.of(context);
    final surfaceColor = tokens.surfacePrimary;
    final dividerColor = tokens.borderMedium;
    final textSecondary = tokens.textSecondary;
    final textPrimary = tokens.textPrimary;
    final textMuted = tokens.textTertiary;
    final disabledColor = tokens.textLight;

    return Container(
      height: kAppFrameHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          if (widget.onMenuPressed != null) ...[
            IconButton(
              tooltip: 'Mở menu',
              icon: Icon(Icons.menu, color: textSecondary),
              onPressed: widget.onMenuPressed,
            ),
            const SizedBox(width: AppSpacing.s),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Icon(
                    _getRouteIcon(widget.currentRoute),
                    size: 16,
                    color: tokens.textSecondary,
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
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                )
                              : AppTextStyles.body.copyWith(color: textMuted),
                        ),
                        if (!isLast) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: disabledColor,
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
          Tooltip(
            message: 'Tìm kiếm & Command Palette (Ctrl+K)',
            child: InkWell(
              key: const ValueKey('global_search_button'),
              borderRadius: BorderRadius.circular(8),
              hoverColor: tokens.transparentLighter,
              onTap: () => showCommandPaletteDialog(context),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: tokens.surfaceSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderMedium, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, size: 15, color: textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Tìm kiếm...',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceQuaternary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Ctrl K',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                key: const ValueKey('notification_bell_button'),
                tooltip: 'Thông báo',
                icon: Icon(Icons.notifications_outlined, color: textSecondary),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const _NotificationMenuDialog(),
                  );
                },
              ),
              if (notifCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      notifCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.s),
          Builder(
            builder: (context) {
              final ZaloActionType? actionType;
              if (widget.currentRoute.startsWith('/messaging/bulk')) {
                final bulkState = ref.watch(bulkMessagingProvider);
                if (bulkState.selectedTab == 0) {
                  actionType = ZaloActionType.bulkMessageByPhone;
                } else if (bulkState.selectedTab == 1) {
                  actionType = ZaloActionType.bulkMessageToGroup;
                } else if (bulkState.selectedTab == 2 || bulkState.selectedTab == 3) {
                  actionType = ZaloActionType.bulkMessageToFriends;
                } else {
                  actionType = ZaloActionType.bulkMessageByPhone;
                }
              } else if (widget.currentRoute.startsWith(
                '/messaging/live-chat',
              )) {
                actionType = ZaloActionType.liveChatReply;
              } else if (widget.currentRoute.startsWith('/messaging/chatbot')) {
                actionType = ZaloActionType.chatbotReply;
              } else if (widget.currentRoute.startsWith('/friends/by-phone')) {
                actionType = ZaloActionType.friendByPhone;
              } else if (widget.currentRoute.startsWith('/friends/by-group')) {
                actionType = ZaloActionType.friendByGroup;
              } else if (widget.currentRoute.startsWith('/groups/join')) {
                actionType = ZaloActionType.joinGroups;
              } else if (widget.currentRoute.startsWith('/groups/invite')) {
                actionType = ZaloActionType.inviteToGroup;
              } else if (widget.currentRoute.startsWith('/groups/create')) {
                actionType = ZaloActionType.createGroups;
              } else {
                actionType = null;
              }
              return WarningIconButton(actionType: actionType);
            },
          ),
        ],
      ),
    );
  }

  IconData _getRouteIcon(String route) {
    if (route.startsWith('/dashboard')) return Icons.dashboard_outlined;
    if (route.startsWith('/customers')) return Icons.people_outline;
    if (route.startsWith('/content')) return Icons.quickreply_outlined;
    if (route.startsWith('/workflows')) return Icons.account_tree_outlined;
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
      return ['Alpha CRM', 'Khách hàng', 'CRM Khách hàng'];
    }
    if (route.startsWith('/content/templates')) {
      return ['Alpha CRM', 'Chiến dịch', 'Tin nhắn mẫu'];
    }
    if (route.startsWith('/workflows')) {
      return ['Alpha CRM', 'Tự động hóa', 'Kho workflow mẫu'];
    }
    if (route.startsWith('/messaging/bulk')) {
      return ['Chức năng nhắn tin', 'Gửi tin hàng loạt'];
    }
    if (route.startsWith('/messaging/live-chat')) {
      return ['Chức năng nhắn tin', 'Hộp thư Live Chat CRM'];
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

class _NotificationMenuDialog extends ConsumerWidget {
  const _NotificationMenuDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zaloState = ref.watch(zaloIntegrationProvider);
    final liveChatState = ref.watch(liveChatProvider);
    final tasksState = ref.watch(crmTasksProvider);
    final authState = ref.watch(crmAuthProvider);

    final List<_NotificationItem> notifications = [];

    if (!zaloState.isBackendActive) {
      notifications.add(
        const _NotificationItem(
          title: 'Zalo Bot mất kết nối',
          detail:
              'Đường truyền dịch vụ Zalo Bot cục bộ đang tắt hoặc không hoạt động.',
          icon: Icons.error_outline,
          color: AppColors.error,
          route: AppRoutes.settings,
        ),
      );
    }

    for (final acc in zaloState.accounts) {
      if (!acc.connected) {
        notifications.add(
          _NotificationItem(
            title: 'Tài khoản mất kết nối',
            detail:
                'Tài khoản Zalo "${acc.label}" đã bị đăng xuất hoặc ngắt kết nối.',
            icon: Icons.warning_amber_rounded,
            color: AppColors.warning,
            route: AppRoutes.settings,
          ),
        );
      } else if (!acc.listenerRunning) {
        notifications.add(
          _NotificationItem(
            title: 'Lắng nghe tin nhắn dừng',
            detail:
                'Tiến trình nhận tin nhắn của "${acc.label}" đang tạm dừng.',
            icon: Icons.pause_circle_outline,
            color: AppColors.warning,
            route: AppRoutes.settings,
          ),
        );
      }
    }

    if (zaloState.agentError != null) {
      notifications.add(
        _NotificationItem(
          title: 'Lỗi Zalo Bot Agent',
          detail: zaloState.agentError!,
          icon: Icons.bug_report_outlined,
          color: AppColors.error,
          route: AppRoutes.settings,
        ),
      );
    }

    for (final conv in liveChatState.conversations) {
      if (conv.unreadCount > 0) {
        notifications.add(
          _NotificationItem(
            title: 'Tin nhắn chưa đọc',
            detail:
                'Bạn có ${conv.unreadCount} tin nhắn mới từ "${conv.customerName}".',
            icon: Icons.mark_chat_unread_outlined,
            color: AppColors.primary,
            route: AppRoutes.messagingLiveChat,
          ),
        );
      }
    }

    final now = DateTime.now();
    for (final task in tasksState.tasks) {
      if (task.status != 'completed' &&
          task.dueAt != null &&
          task.dueAt!.isBefore(now)) {
        notifications.add(
          _NotificationItem(
            title: 'Công việc quá hạn',
            detail:
                'Công việc "${task.title}" đã quá hạn vào lúc ${task.dueAt.toString().substring(0, 16)}.',
            icon: Icons.alarm_on_outlined,
            color: AppColors.error,
            route: AppRoutes.tasks,
          ),
        );
      }
    }

    final subscriptionStatus = authState.subscriptionStatus;
    final hasKnownSubscriptionWarning =
        authState.isAuthenticated &&
        subscriptionStatus != null &&
        subscriptionStatus != 'active';
    if (hasKnownSubscriptionWarning) {
      notifications.add(
        const _NotificationItem(
          title: 'Gói dịch vụ hết hạn',
          detail:
              'Vui lòng gia hạn gói Alpha CRM để tiếp tục sử dụng bot gửi tin.',
          icon: Icons.credit_card_off_outlined,
          color: AppColors.error,
          route: AppRoutes.subscription,
        ),
      );
    }

    return AppDialog(
      key: const ValueKey('notification_menu'),
      title: 'Thông báo hệ thống',
      icon: Icons.notifications_active_outlined,
      width: 500,
      child: SizedBox(
        height: 350,
        child: notifications.isEmpty
            ? Center(
                child: Text(
                  'Không có thông báo mới nào.',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : AppColors.textMuted,
                  ),
                ),
              )
            : ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: notifications.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = notifications[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: item.color.withValues(alpha: 0.1),
                      child: Icon(item.icon, color: item.color),
                    ),
                    title: Text(
                      item.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      item.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (item.route != null) {
                        context.go(item.route!);
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _NotificationItem {
  final String title;
  final String detail;
  final IconData icon;
  final Color color;
  final String? route;

  const _NotificationItem({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
    this.route,
  });
}
