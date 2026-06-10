import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_shell_providers.dart';
import 'nav_item_models.dart';
import '../../shared/utils/responsive_breakpoints.dart';
import '../../features/auth/providers/crm_auth_provider.dart';
import '../../features/security/providers/app_lock_provider.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final surfaceColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final dividerColor = theme.dividerTheme.color ?? theme.dividerColor;
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : AppColors.textSecondary;

    final bool isCollapsed =
        forceCollapsed ?? ref.watch(sidebarCollapsedProvider);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

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
                    return _buildGroup(context, group, isCollapsed);
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
            right: -12, // overlapping the right border (which is 1px wide)
            top:
                52, // centered around y = 64px (since button height is 24px, 64 - 12 = 52px)
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  ref.read(sidebarCollapsedProvider.notifier).state =
                      !isCollapsed;
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: dividerColor, width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.05),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                    size: 14,
                    color: textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBrandingHeader(BuildContext context, bool isCollapsed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.textPrimary;
    final textMuted = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : AppColors.textMuted;

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? AppSpacing.m : AppSpacing.m,
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
              gradient: const LinearGradient(
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
                      Text(
                        'ALPHA CRM',
                        style: AppTextStyles.cardTitle.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w800,
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
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  Text(
                    'PHẦN MỀM MARKETING',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, NavGroup group, bool isCollapsed) {
    final hasActiveItem = group.items.any(
      (item) => currentRoute == item.routePath,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : AppColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isCollapsed)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.m,
              top: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              group.groupName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? (hasActiveItem ? Colors.white.withValues(alpha: 0.9) : textMuted)
                    : (hasActiveItem ? AppColors.primary : textMuted),
                letterSpacing: 1.0,
              ),
            ),
          )
        else
          const SizedBox(height: AppSpacing.s),
        ...group.items.map((item) => _buildNavItem(context, item, isCollapsed)),
      ],
    );
  }

  Widget _buildNavItem(BuildContext context, NavItem item, bool isCollapsed) {
    final isActive = currentRoute == item.routePath;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : AppColors.textSecondary;
    final activeBg = _activeBgColor(item, isDark);
    final activeIcon = _activeIconColor(item, isDark);

    final Color itemTextColor;
    final Color itemIconColor;
    if (isDark) {
      itemTextColor = isActive ? Colors.white : Colors.white.withValues(alpha: 0.7);
      itemIconColor = isActive ? activeIcon : Colors.white.withValues(alpha: 0.6);
    } else {
      itemTextColor = isActive ? activeIcon : textSecondary;
      itemIconColor = isActive ? activeIcon : textSecondary;
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
                child: Icon(
                  item.icon,
                  color: itemIconColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Nav item button body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
                      const SizedBox(width: AppSpacing.m),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.textPrimary;
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : AppColors.textSecondary;
    final textMuted = isDark
        ? Colors.white.withValues(alpha: 0.5)
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
      padding: const EdgeInsets.all(AppSpacing.m),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primarySoft = isDark
        ? const Color(0xFF1E293B)
        : AppColors.primarySoft;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: primarySoft, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  void _showLogoutConfirmDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : AppColors.textSecondary;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng Alpha CRM?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(crmAuthProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  Color _activeIconColor(NavItem item, bool isDark) {
    final path = item.routePath;
    if (isDark && path == '/settings') return const Color(0xFF94A3B8);
    if (path == '/dashboard') return const Color(0xFFF97316);
    if (path == '/customers') return const Color(0xFF0068FF);
    if (path == '/tasks') return const Color(0xFF10B981);
    if (path == '/workflows') return const Color(0xFF8B5CF6);
    if (path == '/messaging/bulk') return const Color(0xFF6366F1);
    if (path == '/messaging/live-chat') return const Color(0xFF0D9488);
    if (path == '/messaging/chatbot') return const Color(0xFFD946EF);
    if (path == '/messaging/history') return const Color(0xFF64748B);
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
