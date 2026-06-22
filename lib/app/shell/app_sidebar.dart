import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_button.dart';
import 'app_shell_providers.dart';
import 'nav_item_models.dart';
import '../../shared/utils/responsive_breakpoints.dart';
import '../../features/auth/providers/crm_auth_provider.dart';
import '../../features/security/providers/app_lock_provider.dart';
import '../../features/tasks/providers/crm_tasks_provider.dart';
import '../../features/messaging/bulk/providers/scheduled_campaigns_provider.dart';

class AppSidebar extends ConsumerWidget {
  final String currentRoute;
  final bool? forceCollapsed;

  const AppSidebar({
    super.key,
    required this.currentRoute,
    this.forceCollapsed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Force dark blue (xanh đen) theme cho toàn bộ sidebar
    final surfaceColor = const Color(0xFF0F172A); // Xanh đen (Slate 900)
    final dividerColor = const Color(0xFF1E293B); // Xanh đen nhạt hơn (Slate 800)
    final textSecondary = Colors.white.withValues(alpha: 0.85); // Thay đổi từ 0.7 sang 0.85 để sáng hơn

    final bool isCollapsed =
        forceCollapsed ?? ref.watch(sidebarCollapsedProvider);
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final int openTaskCount = ref.watch(
      crmTasksProvider.select((s) => s.openCount),
    );
    final int scheduledCount = ref.watch(
      scheduledCampaignsProvider.select((s) => s.length),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: isCollapsed ? 72 : 250,
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(right: BorderSide(color: dividerColor, width: 1)),
          ),
          child: Column(
            children: [
              // Branding Header
              _buildBrandingHeader(context, isCollapsed),
              const Divider(height: 1),

              // Navigation List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  children: navigationGroups.map((group) {
                    return _SidebarGroupWidget(
                      group: group,
                      isCollapsed: isCollapsed,
                      currentRoute: currentRoute,
                      buildItem: (item, isCollapsed) => _buildNavItem(
                        context,
                        item,
                        isCollapsed,
                        openTaskCount,
                        scheduledCount,
                      ),
                    );
                  }).toList(),
                ),
              ),

              // User Footer & Logout Section
              const Divider(height: 1),
              _buildUserFooter(context, ref, isCollapsed),
            ],
          ),
        ),
        // Circular Collapse Button on the right border
        if (!isMobile && forceCollapsed == null)
          Positioned(
            right: -16, // overlapping the right border
            top:
                48, // centered around y = 64px (since button height is 32px, 64 - 16 = 48px)
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  ref.read(sidebarCollapsedProvider.notifier).state =
                      !isCollapsed;
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary, // Different prominent color
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.15),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                    size: 20,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBrandingHeader(BuildContext context, bool isCollapsed) {
    final textPrimary = const Color(0xFFFFFFFF);
    final textMuted = Colors.white.withValues(alpha: 0.75); // Sáng hơn một chút so với white60

    return Container(
      height: 64,
      color: const Color(0xFF0F172A), // Cùng màu xanh đen với sidebar
      padding: EdgeInsets.only(
        left: isCollapsed ? AppSpacing.m : AppSpacing.s,
        right: AppSpacing.m,
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: isCollapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          // Avatar Letter 'M' with Gradient
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.zaloBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            ),
            alignment: Alignment.center,
            child: const Text(
              'M',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'ALPHA CRM',
                          style: AppTextStyles.cardTitle.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Text(
                              'v${snapshot.data!.version}',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'PHẦN MỀM MARKETING',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.95),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.isDarkMode 
                              ? Colors.amber.withValues(alpha: 0.3) 
                              : Colors.orange.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.isDarkMode 
                                ? Colors.amber.withValues(alpha: 0.8) 
                                : Colors.orange.withValues(alpha: 0.8),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome, // Thay cho icon Beta
                              size: 10,
                              color: AppColors.isDarkMode 
                                  ? Colors.yellowAccent 
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'BETA',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: AppColors.isDarkMode 
                                    ? Colors.yellowAccent 
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    NavItem item,
    bool isCollapsed, [
    int openTaskCount = 0,
    int scheduledCount = 0,
  ]) {
    final isActive = currentRoute == item.routePath;
    final int badgeCount = item.routePath == '/messaging/bulk'
        ? scheduledCount
        : (item.routePath == '/tasks' ? openTaskCount : 0);
    final bool showBadge = badgeCount > 0;
    final isDark = true; // Force dark sidebar
    final textSecondary = Colors.white.withValues(alpha: 0.85); // Sáng hơn
    final activeBg = _activeBgColor(item, isDark);
    final activeIcon = _activeIconColor(item, isDark);

    final Color itemTextColor;
    final Color itemIconColor;
    if (isDark) {
      itemTextColor = isActive ? Colors.white : Colors.white.withValues(alpha: 0.85); // Sáng hơn
      itemIconColor = item.color ?? (isActive ? activeIcon : Colors.white.withValues(alpha: 0.75)); // Sáng hơn
    } else {
      itemTextColor = isActive ? activeIcon : textSecondary;
      itemIconColor = item.color ?? (isActive ? activeIcon : textSecondary);
    }

    if (isCollapsed) {
      return Tooltip(
        message: item.title,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: AppSpacing.xs,
          ),
          height: 40,
          child: Material(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusS),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusS),
              onTap: () => context.go(item.routePath),
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(item.icon, color: itemIconColor, size: 20),
                    if (showBadge)
                      Positioned(
                        right: -7,
                        top: -6,
                        child: _NavCountBadge(count: badgeCount),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Nav item button body
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.s, right: AppSpacing.sm),
            child: Material(
              color: isActive ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusS),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                onTap: () => context.go(item.routePath),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        item.icon,
                        color: itemIconColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: itemTextColor,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showBadge) ...[
                        _NavCountBadge(count: badgeCount),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Active left border line
          if (isActive)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3.5,
              child: Container(
                decoration: BoxDecoration(
                  color: activeIcon,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(3),
                    bottomRight: Radius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserFooter(
    BuildContext context,
    WidgetRef ref,
    bool isCollapsed,
  ) {
    final isDark = true; // Force dark sidebar
    final textPrimary = const Color(0xFFF8FAFC);
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.85) // Sáng hơn
        : AppColors.textSecondary;
    final textMuted = isDark
        ? Colors.white.withValues(alpha: 0.75) // Sáng hơn
        : AppColors.textMuted;
    final surfaceMuted = isDark
        ? const Color(0xFF162033)
        : AppColors.surfaceMuted;

    final authState = ref.watch(crmAuthProvider);
    final user = authState.user;
    final displayName = user?.name ?? user?.email ?? 'Người dùng';
    final role = user?.role ?? 'Thành viên';

    final avatarWidget = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: user?.avatar != null && user!.avatar!.isNotEmpty
          ? Image.network(
              user.avatar!,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildDefaultAvatar(context, displayName),
            )
          : _buildDefaultAvatar(context, displayName),
    );

    if (isCollapsed) {
      return Tooltip(
        message: 'Đăng xuất ($displayName)',
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: AppSpacing.m,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusS),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusS),
              onTap: () => _showLogoutConfirmDialog(context, ref),
              child: SizedBox(
                height: 40,
                width: 40,
                child: Center(child: avatarWidget),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.sm, right: AppSpacing.sm, top: AppSpacing.m, bottom: AppSpacing.m),
      decoration: BoxDecoration(color: surfaceMuted),
      child: Row(
        children: [
          // User Avatar Circle
          avatarWidget,
          const SizedBox(width: AppSpacing.s),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  role,
                  style: AppTextStyles.caption.copyWith(
                    color: textMuted,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            icon: const Icon(Icons.lock_outline_rounded, size: 18),
            color: textSecondary,
            tooltip: 'Khóa ứng dụng',
            onPressed: () => ref.read(appLockProvider.notifier).lock(),
          ),
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            color: textSecondary,
            tooltip: 'Đăng xuất',
            onPressed: () => _showLogoutConfirmDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(BuildContext context, String displayName) {
    final isDark = true; // Force dark sidebar
    final primarySoft = const Color(0xFF1E293B);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: primarySoft, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  void _showLogoutConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: 'Xác nhận đăng xuất',
        icon: Icons.logout_rounded,
        width: 460,
        actions: [
          AppDialogAction(
            text: 'Hủy',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.pop(context),
          ),
          AppDialogAction(
            text: 'Đăng xuất',
            variant: AppButtonVariant.destructive,
            onPressed: () {
              Navigator.pop(context);
              ref.read(crmAuthProvider.notifier).logout();
            },
          ),
        ],
        child: Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng Alpha CRM?',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );
  }

  Color _activeIconColor(NavItem item, bool isDark) {
    final path = item.routePath;
    if (isDark && path == '/settings') return Colors.white;
    if (path == '/dashboard') return const Color(0xFFF97316);
    if (path == '/customers') return const Color(0xFF0068FF);
    if (path == '/tasks') return const Color(0xFF10B981);
    if (path == '/workflows') return const Color(0xFF8B5CF6);
    if (path == '/messaging/bulk') return const Color(0xFF6366F1);
    if (path == '/messaging/live-chat') return const Color(0xFF0D9488);
    if (path == '/messaging/chatbot') return const Color(0xFFD946EF);
    if (path == '/messaging/history') return Colors.white60;
    if (path.startsWith('/friends')) return const Color(0xFF059669);
    if (path.startsWith('/groups')) return const Color(0xFF0891B2);
    if (path == '/subscription') return const Color(0xFFEC4899);
    if (path == '/devices') return const Color(0xFF7C3AED);
    if (path == '/settings') return const Color(0xFF475569);
    return AppColors.primary;
  }

  Color _activeBgColor(NavItem item, bool isDark) {
    if (isDark) {
      return _activeIconColor(item, true).withValues(alpha: 0.15);
    }
    final path = item.routePath;
    if (path == '/dashboard') return const Color(0xFFFFF7ED);
    if (path == '/customers') return const Color(0xFFF0F9FF);
    if (path == '/tasks') return const Color(0xFFF0FDF4);
    if (path == '/workflows') return const Color(0xFFF5F3FF);
    if (path == '/messaging/bulk') return const Color(0xFFEEF2FF);
    if (path == '/messaging/live-chat') return const Color(0xFFF0FDFA);
    if (path == '/messaging/chatbot') return const Color(0xFFFDF4FF);
    if (path == '/messaging/history') return const Color(0xFFF8FAFC);
    if (path.startsWith('/friends')) return const Color(0xFFECFDF5);
    if (path.startsWith('/groups')) return const Color(0xFFECFEFF);
    if (path == '/subscription') return const Color(0xFFFDF2F8);
    if (path == '/devices') return const Color(0xFFF5F3FF);
    if (path == '/settings') return const Color(0xFFF1F5F9);
    return AppColors.primarySoft;
  }
}

/// Red pill showing a pending count (e.g. open follow-up tasks) on a nav item.
class _NavCountBadge extends StatelessWidget {
  final int count;

  const _NavCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}

class _SidebarGroupWidget extends StatefulWidget {
  final NavGroup group;
  final bool isCollapsed;
  final String currentRoute;
  final Widget Function(NavItem item, bool isCollapsed) buildItem;

  const _SidebarGroupWidget({
    required this.group,
    required this.isCollapsed,
    required this.currentRoute,
    required this.buildItem,
  });

  @override
  State<_SidebarGroupWidget> createState() => _SidebarGroupWidgetState();
}

class _SidebarGroupWidgetState extends State<_SidebarGroupWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.group.defaultExpanded;
    // Tự động mở rộng nếu đang ở màn hình thuộc nhóm này
    if (widget.group.items.any((item) => widget.currentRoute == item.routePath)) {
      _isExpanded = true;
    }
  }

  @override
  void didUpdateWidget(_SidebarGroupWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentRoute != oldWidget.currentRoute) {
      if (widget.group.items.any((item) => widget.currentRoute == item.routePath)) {
        setState(() {
          _isExpanded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveItem = widget.group.items.any(
      (item) => widget.currentRoute == item.routePath,
    );
    final isDark = true;
    final textMuted = Colors.white.withValues(alpha: 0.65); // Sáng hơn một chút so với 0.4 trước đây
    final activeGroupColor = const Color(0xFF60A5FA); // Màu xanh nhạt (Blue 400) để nổi bật khi kích hoạt

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isCollapsed)
          InkWell(
            onTap: widget.group.isCollapsible
                ? () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                top: AppSpacing.m,
                bottom: AppSpacing.xs,
                right: AppSpacing.m,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.group.groupName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? (hasActiveItem ? activeGroupColor : textMuted)
                            : (hasActiveItem ? activeGroupColor : textMuted),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  if (widget.group.isCollapsible)
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: hasActiveItem ? activeGroupColor : textMuted,
                    ),
                ],
              ),
            ),
          )
        else
          const SizedBox(height: AppSpacing.s),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.group.items
                .map((item) => widget.buildItem(item, widget.isCollapsed))
                .toList(),
          ),
          crossFadeState: (widget.isCollapsed || _isExpanded || !widget.group.isCollapsible)
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

