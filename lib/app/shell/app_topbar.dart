import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../routing/app_routes.dart';
import '../../shared/widgets/compliance_warnings_popup.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_button.dart';

import '../../features/customers/providers/customers_provider.dart';
import '../../features/messaging/live_chat/providers/live_chat_provider.dart';
import '../../features/tasks/providers/crm_tasks_provider.dart';
import '../../features/zalo_integration/providers/zalo_integration_provider.dart';
import '../../features/auth/providers/crm_auth_provider.dart';

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEAF1FF); // Xanh lam nhạt hoặc dark
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFBFD2FF); // Viền xanh lam nhạt hoặc dark
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569); // Text màu đậm để dễ đọc
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF64748B) : const Color(0xFF718096);
    final disabledColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return Container(
      height: 64,
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
          IconButton(
            key: const ValueKey('global_search_button'),
            tooltip: 'Tìm kiếm toàn cầu',
            icon: Icon(Icons.search, color: textSecondary),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const _GlobalSearchDialog(),
              );
            },
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
                actionType = ZaloActionType.bulkMessageByPhone;
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
              } else if (widget.currentRoute.startsWith(
                '/groups/scan-members',
              )) {
                actionType = ZaloActionType.scanGroupMembers;
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

class _GlobalSearchDialog extends ConsumerStatefulWidget {
  const _GlobalSearchDialog();

  @override
  ConsumerState<_GlobalSearchDialog> createState() =>
      _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends ConsumerState<_GlobalSearchDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(String input) {
    var str = input.toLowerCase().trim();
    const vietnamese =
        'aáàảãạâấầẩẫậăắằẳẵặeéèẻẽẹêếềểễệiíìỉĩịoóòỏõọôốồổỗộơớờởỡợuúùủũụưứừửữựyýỳỷỹỵdđ';
    const english =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeeiiiiiiioooooooooooooooooouuuuuuuuuuuuyyyyyydd';

    for (int i = 0; i < vietnamese.length; i++) {
      str = str.replaceAll(vietnamese[i], english[i]);
    }
    return str;
  }

  String _digitsOnly(String input) => input.replaceAll(RegExp(r'\D'), '');

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customersProvider);
    final liveChatState = ref.watch(liveChatProvider);
    final tasksState = ref.watch(crmTasksProvider);

    final normalizedQuery = _normalize(_query);
    final List<_SearchResult> results = [];

    if (normalizedQuery.isNotEmpty) {
      final queryDigits = _digitsOnly(_query);
      // Search contacts
      for (final contact in customersState.contacts) {
        if (_normalize(contact.name).contains(normalizedQuery) ||
            (queryDigits.isNotEmpty &&
                _digitsOnly(contact.phone).contains(queryDigits)) ||
            _normalize(contact.group).contains(normalizedQuery) ||
            _normalize(contact.tag).contains(normalizedQuery) ||
            _normalize(contact.source).contains(normalizedQuery) ||
            _normalize(contact.status).contains(normalizedQuery)) {
          results.add(
            _SearchResult(
              title: contact.name,
              subtitle: 'Khách hàng • ${contact.phone} • ${contact.status}',
              route: AppRoutes.customers,
              icon: Icons.person_outline,
              extra: contact.group,
            ),
          );
        }
      }

      // Search live chat threads
      for (final conv in liveChatState.conversations) {
        if (_normalize(conv.customerName).contains(normalizedQuery) ||
            conv.threadId.contains(normalizedQuery) ||
            _normalize(conv.lastMessage).contains(normalizedQuery) ||
            _normalize(conv.tag).contains(normalizedQuery)) {
          results.add(
            _SearchResult(
              title: conv.customerName,
              subtitle: 'Live Chat • ${conv.lastMessage}',
              route: AppRoutes.messagingLiveChat,
              icon: Icons.chat_bubble_outline,
              extra: conv.tag.isNotEmpty ? conv.tag : null,
            ),
          );
        }
      }

      // Search tasks
      for (final task in tasksState.tasks) {
        if (_normalize(task.title).contains(normalizedQuery) ||
            _normalize(task.description).contains(normalizedQuery) ||
            _normalize(task.priority).contains(normalizedQuery) ||
            _normalize(task.status).contains(normalizedQuery)) {
          results.add(
            _SearchResult(
              title: task.title,
              subtitle: 'Công việc • ${task.description}',
              route: AppRoutes.tasks,
              icon: Icons.task_alt_outlined,
              extra: 'Ưu tiên: ${task.priority.toUpperCase()}',
            ),
          );
        }
      }
    }

    return AppDialog(
      key: const ValueKey('global_search_panel'),
      title: 'Tìm kiếm toàn cầu',
      icon: Icons.search,
      width: 600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm khách hàng, hội thoại, công việc...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              setState(() {
                _query = val;
              });
            },
          ),
          const SizedBox(height: AppSpacing.m),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            height: 350,
            child: _query.isEmpty
                ? Center(
                    child: Text(
                      'Nhập từ khóa để bắt đầu tìm kiếm...',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF64748B)
                            : AppColors.textMuted,
                      ),
                    ),
                  )
                : results.isEmpty
                ? Center(
                    child: Text(
                      'Không tìm thấy kết quả phù hợp.',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF64748B)
                            : AppColors.textMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: results.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(item.icon, color: AppColors.primary),
                        title: Text(
                          item.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: item.extra != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF1E293B)
                                          : AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusS,
                                  ),
                                ),
                                child: Text(
                                  item.extra!,
                                  style: AppTextStyles.caption.copyWith(
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF60A5FA)
                                            : AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          context.go(item.route);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchResult {
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  final String? extra;

  const _SearchResult({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
    this.extra,
  });
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
                        ? const Color(0xFF64748B)
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
