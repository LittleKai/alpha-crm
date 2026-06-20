import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shell/app_shell.dart';
import 'app_routes.dart';

// Import Screens
import '../../features/dashboard/presentation/screens/dashboard_screen_placeholder.dart';
import '../../features/customers/presentation/screens/customers_screen_placeholder.dart';
import '../../features/content/presentation/screens/content_templates_screen_placeholder.dart';
import '../../features/workflows/presentation/screens/workflow_automation_screen.dart';
import '../../features/messaging/bulk/presentation/screens/bulk_messaging_screen_placeholder.dart';
import '../../features/messaging/live_chat/presentation/screens/live_chat_screen_placeholder.dart';
import '../../features/messaging/chatbot/presentation/screens/chatbot_screen_placeholder.dart';
import '../../features/messaging/history/presentation/screens/send_history_screen_placeholder.dart';
import '../../features/friends/by_phone/presentation/screens/friend_by_phone_screen_placeholder.dart';
import '../../features/friends/by_group/presentation/screens/friend_by_group_screen_placeholder.dart';
import '../../features/friends/auto_approve/presentation/screens/auto_approve_screen_placeholder.dart';
import '../../features/friends/history/presentation/screens/friend_history_screen_placeholder.dart';
import '../../features/groups/presentation/screens/scan_members_screen_placeholder.dart';
import '../../features/groups/presentation/screens/join_groups_screen_placeholder.dart';
import '../../features/groups/presentation/screens/invite_to_group_screen_placeholder.dart';
import '../../features/groups/presentation/screens/create_groups_screen_placeholder.dart';
import '../../features/groups/presentation/screens/leave_groups_screen_placeholder.dart';
import '../../features/groups/manage/presentation/screens/managed_groups_screen.dart';
import '../../features/tasks/presentation/screens/crm_tasks_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/system_logs_screen.dart';
import '../../features/auth/presentation/screens/crm_login_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/devices/presentation/screens/device_pairing_screen.dart';
import '../../features/auth/providers/crm_auth_provider.dart';

/// Cầu nối auth state -> GoRouter.refreshListenable. Cho phép redirect chạy lại
/// khi auth đổi mà KHÔNG tạo lại GoRouter (giữ nguyên tab/route hiện tại).
class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

// GoRouter Riverpod Provider
//
// Provider này KHÔNG `watch` auth state nên GoRouter chỉ được tạo MỘT lần và
// không bao giờ bị tái tạo (tránh việc reset về initialLocation = dashboard mỗi
// khi auth/subscription load xong). Thay đổi auth được đẩy vào redirect qua
// refreshListenable.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(
    crmAuthProvider.select((s) => (s.isAuthenticated, s.isLoading)),
    (_, _) => refresh.ping(),
  );

  final router = GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(crmAuthProvider);
      final isLoggingIn = state.uri.path == AppRoutes.login;

      if (auth.isLoading) return null;

      if (!auth.isAuthenticated) {
        return isLoggingIn ? null : AppRoutes.login;
      }

      if (isLoggingIn) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      // Màn hình đăng nhập đứng độc lập không nằm trong ShellRoute
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const CrmLoginScreen(),
      ),

      // Chuyển hướng '/' về '/dashboard'
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.dashboard),

      // Shell Route chứa tất cả màn hình giao diện CRM chính kèm Sidebar
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(state: state, child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.customers,
            builder: (context, state) => const CustomersScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.contentTemplates,
            builder: (context, state) =>
                const ContentTemplatesScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.workflows,
            builder: (context, state) => const WorkflowAutomationScreen(),
          ),
          GoRoute(
            path: AppRoutes.messagingBulk,
            builder: (context, state) => const BulkMessagingScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.messagingLiveChat,
            builder: (context, state) => const LiveChatScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.messagingChatbot,
            builder: (context, state) => const ChatbotScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.messagingHistory,
            builder: (context, state) => const SendHistoryScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.friendsByPhone,
            builder: (context, state) => const FriendByPhoneScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.friendsByGroup,
            builder: (context, state) => const FriendByGroupScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.friendsAutoApprove,
            builder: (context, state) => const AutoApproveScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.friendsHistory,
            builder: (context, state) => const FriendHistoryScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.groupsScanMembers,
            builder: (context, state) => const ScanMembersScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.groupsJoin,
            builder: (context, state) => const JoinGroupsScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.groupsInvite,
            builder: (context, state) => const InviteToGroupScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.groupsCreate,
            builder: (context, state) => const CreateGroupsScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.groupsLeave,
            builder: (context, state) => const LeaveGroupsScreenPlaceholder(),
          ),
          GoRoute(
            path: AppRoutes.groupsManage,
            builder: (context, state) => const ManagedGroupsScreen(),
          ),
          GoRoute(
            path: AppRoutes.tasks,
            builder: (context, state) => const CrmTasksScreen(),
          ),
          GoRoute(
            path: AppRoutes.subscription,
            builder: (context, state) => const SubscriptionScreen(),
          ),
          GoRoute(
            path: AppRoutes.devices,
            builder: (context, state) => const DevicePairingScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.systemLogs,
            builder: (context, state) => const SystemLogsScreen(),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    refresh.dispose();
    router.dispose();
  });

  return router;
});

// Fallback legacy global appRouter instance to prevent compilation failures
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.dashboard,
  routes: [
    GoRoute(path: '/', redirect: (context, state) => AppRoutes.dashboard),
    ShellRoute(
      builder: (context, state, child) {
        return AppShell(state: state, child: child);
      },
      routes: [
        GoRoute(
          path: AppRoutes.dashboard,
          builder: (context, state) => const DashboardScreenPlaceholder(),
        ),
      ],
    ),
  ],
);
