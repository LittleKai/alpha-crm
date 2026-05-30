import 'package:go_router/go_router.dart';
import '../shell/app_shell.dart';
import 'app_routes.dart';

// Import Screen Placeholders
import '../../features/dashboard/presentation/screens/dashboard_screen_placeholder.dart';
import '../../features/customers/presentation/screens/customers_screen_placeholder.dart';
import '../../features/content/presentation/screens/content_templates_screen_placeholder.dart';
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
import '../../features/settings/presentation/screens/settings_screen_placeholder.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.dashboard,
  routes: [
    // Redirect from root '/' to '/dashboard'
    GoRoute(path: '/', redirect: (context, state) => AppRoutes.dashboard),

    // Shell Route wrapping all CRM screens
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
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsScreenPlaceholder(),
        ),
      ],
    ),
  ],
);
