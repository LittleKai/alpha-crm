import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../features/auth/providers/crm_auth_provider.dart';
import '../../features/messaging/bulk/providers/scheduled_campaigns_provider.dart';
import '../../features/security/providers/app_lock_provider.dart';
import '../../features/tasks/providers/crm_tasks_provider.dart';
import '../../shared/utils/responsive_breakpoints.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_dialog.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_tokens.dart';
import 'app_shell_providers.dart';
import 'nav_item_models.dart';

class AppSidebar extends ConsumerWidget {
  static final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  final String currentRoute;
  final bool? forceCollapsed;

  const AppSidebar({
    super.key,
    required this.currentRoute,
    this.forceCollapsed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppThemeTokens.of(context);
    final bool isCollapsed =
        forceCollapsed ?? ref.watch(sidebarCollapsedProvider);
    final double expandedWidth = ref.watch(sidebarWidthProvider);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final int openTaskCount = ref.watch(
      crmTasksProvider.select((s) => s.openCount),
    );
    final int scheduledCount = ref.watch(
      scheduledCampaignsProvider.select((s) => s.length),
    );

    final double width = isCollapsed ? kSidebarCollapsedWidth : expandedWidth;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: const ValueKey('app_sidebar_surface'),
          width: width,
          decoration: BoxDecoration(
            color: tokens.canvasBackground,
            border: isMobile
                ? Border(right: BorderSide(color: tokens.borderMedium, width: 1))
                : null,
          ),
          child: Column(
            children: [
              _buildHeader(context, ref, tokens, isCollapsed, isMobile),
              Divider(height: 1, color: tokens.borderLight),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s,
                    horizontal: AppSpacing.s,
                  ),
                  children: navigationGroups.map((group) {
                    return _SidebarGroupWidget(
                      group: group,
                      isCollapsed: isCollapsed,
                      currentRoute: currentRoute,
                      buildItem: (item, collapsed) => _buildNavItem(
                        context,
                        tokens,
                        item,
                        collapsed,
                        openTaskCount,
                        scheduledCount,
                      ),
                    );
                  }).toList(),
                ),
              ),
              Divider(height: 1, color: tokens.borderMedium),
              _buildUserFooter(context, ref, tokens, isCollapsed),
            ],
          ),
        ),
        if (!isMobile && !isCollapsed && forceCollapsed == null)
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              key: const ValueKey('sidebar_resize_handle'),
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                final nextWidth = ref.read(sidebarWidthProvider) + details.delta.dx;
                persistSidebarWidth(ref, nextWidth, saveToDisk: false);
              },
              onHorizontalDragEnd: (_) {
                persistSidebarWidth(
                  ref,
                  ref.read(sidebarWidthProvider),
                  saveToDisk: true,
                );
              },
              child: const SizedBox(width: 6, height: double.infinity),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AppThemeTokens tokens,
    bool isCollapsed,
    bool isMobile,
  ) {
    final bool canCollapse = !isMobile && forceCollapsed == null;

    if (isCollapsed) {
      return SizedBox(
        height: kAppFrameHeaderHeight,
        child: Center(
          child: Tooltip(
            message: 'Mở rộng thanh điều hướng',
            child: IconButton(
              key: canCollapse ? const ValueKey('sidebar_collapse_button') : null,
              onPressed: canCollapse
                  ? () => persistSidebarCollapsed(ref, false)
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: Icon(
                Icons.keyboard_double_arrow_right_rounded,
                size: 18,
                color: tokens.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: kAppFrameHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: tokens.accentBlue,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Text(
              'A',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'ALPHA CRM',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                FutureBuilder<PackageInfo>(
                  future: _packageInfoFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    return Text(
                      'v${snapshot.data!.version}',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: tokens.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (canCollapse)
            Tooltip(
              message: 'Thu gọn thanh điều hướng',
              child: IconButton(
                key: const ValueKey('sidebar_collapse_button'),
                onPressed: () => persistSidebarCollapsed(ref, true),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                icon: Icon(
                  Icons.keyboard_double_arrow_left_rounded,
                  size: 16,
                  color: tokens.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    AppThemeTokens tokens,
    NavItem item,
    bool isCollapsed,
    int openTaskCount,
    int scheduledCount,
  ) {
    final isActive = currentRoute == item.routePath;
    final int badgeCount = item.routePath == '/messaging/bulk'
        ? scheduledCount
        : (item.routePath == '/tasks' ? openTaskCount : 0);
    final bool showBadge = badgeCount > 0;

    final Color itemFg = isActive ? tokens.textPrimary : tokens.textSecondary;
    final Color activeBg = tokens.transparentLight;

    if (isCollapsed) {
      return Tooltip(
        message: showBadge ? '${item.title} ($badgeCount)' : item.title,
        waitDuration: const Duration(milliseconds: 250),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Center(
            child: Material(
              color: isActive ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                hoverColor: tokens.transparentLighter,
                onTap: () => context.go(item.routePath),
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Icon(item.icon, color: itemFg, size: 17),
                      if (showBadge)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: tokens.accentBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: isActive ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: tokens.transparentLighter,
          onTap: () => context.go(item.routePath),
          child: SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: Row(
                children: [
                  Icon(item.icon, color: itemFg, size: 16),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      item.title,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        color: itemFg,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showBadge)
                    _NavCountBadge(count: badgeCount, tokens: tokens),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserFooter(
    BuildContext context,
    WidgetRef ref,
    AppThemeTokens tokens,
    bool isCollapsed,
  ) {
    final authState = ref.watch(crmAuthProvider);
    final user = authState.user;
    final displayName = user?.name ?? user?.email ?? 'Người dùng';
    final role = user?.role ?? 'Thành viên';

    final avatarWidget = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: user?.avatar != null && user!.avatar!.isNotEmpty
          ? Image.network(
              user.avatar!,
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildDefaultAvatar(tokens, displayName),
            )
          : _buildDefaultAvatar(tokens, displayName),
    );

    if (isCollapsed) {
      return Tooltip(
        message: 'Đăng xuất ($displayName)',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              hoverColor: tokens.transparentLighter,
              onTap: () => _showLogoutConfirmDialog(context, ref),
              child: SizedBox(
                height: 36,
                width: 36,
                child: Center(child: avatarWidget),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.s,
      ),
      color: tokens.canvasBackground,
      child: Row(
        children: [
          avatarWidget,
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12.5,
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  role,
                  style: AppTextStyles.caption.copyWith(
                    color: tokens.textTertiary,
                    fontSize: 10.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline_rounded, size: 16),
            color: tokens.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            tooltip: 'Khóa ứng dụng',
            onPressed: () => ref.read(appLockProvider.notifier).lock(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 16),
            color: tokens.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            tooltip: 'Đăng xuất',
            onPressed: () => _showLogoutConfirmDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(AppThemeTokens tokens, String displayName) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: tokens.surfaceQuaternary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
        style: TextStyle(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showLogoutConfirmDialog(BuildContext context, WidgetRef ref) {
    showStandardDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Xác nhận đăng xuất',
        icon: Icons.logout_rounded,
        width: 460,
        actions: [
          AppDialogAction(
            text: 'Hủy',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.pop(dialogContext),
          ),
          AppDialogAction(
            text: 'Đăng xuất',
            variant: AppButtonVariant.destructive,
            onPressed: () {
              Navigator.pop(dialogContext);
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
}

class _NavCountBadge extends StatelessWidget {
  final int count;
  final AppThemeTokens tokens;

  const _NavCountBadge({required this.count, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: tokens.surfaceQuaternary,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: tokens.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
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
  bool _isHoveringTitle = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.group.defaultExpanded;
    if (widget.group.items.any(
      (item) => widget.currentRoute == item.routePath,
    )) {
      _isExpanded = true;
    }
  }

  @override
  void didUpdateWidget(_SidebarGroupWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentRoute != oldWidget.currentRoute &&
        widget.group.items.any(
          (item) => widget.currentRoute == item.routePath,
        )) {
      setState(() {
        _isExpanded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isCollapsed)
          MouseRegion(
            onEnter: (_) => setState(() => _isHoveringTitle = true),
            onExit: (_) => setState(() => _isHoveringTitle = false),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              hoverColor: tokens.transparentLighter,
              onTap: widget.group.isCollapsible
                  ? () => setState(() => _isExpanded = !_isExpanded)
                  : null,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.s,
                  right: AppSpacing.xs,
                  top: AppSpacing.sm,
                  bottom: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.group.groupName,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: _isHoveringTitle
                              ? tokens.textSecondary
                              : tokens.textTertiary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (widget.group.isCollapsible)
                      AnimatedOpacity(
                        opacity: (_isHoveringTitle || !_isExpanded) ? 1.0 : 0.35,
                        duration: const Duration(milliseconds: 120),
                        child: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_right_rounded,
                          size: 14,
                          color: tokens.textTertiary,
                        ),
                      ),
                  ],
                ),
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
          crossFadeState:
              (widget.isCollapsed || _isExpanded || !widget.group.isCollapsible)
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 160),
        ),
      ],
    );
  }
}
