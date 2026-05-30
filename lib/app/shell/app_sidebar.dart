import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_shell_providers.dart';
import 'nav_item_models.dart';

class AppSidebar extends ConsumerWidget {
  final String currentRoute;

  const AppSidebar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);

    return Container(
      width: isCollapsed ? 72 : 250,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Branding Header
          _buildBrandingHeader(isCollapsed),
          const Divider(height: 1, color: AppColors.borderSoft),

          // Navigation List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: navigationGroups.map((group) {
                return _buildGroup(context, group, isCollapsed);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingHeader(bool isCollapsed) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? AppSpacing.m : AppSpacing.m,
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment:
            isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
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
                  Text(
                    'CRM ZALO',
                    style: AppTextStyles.cardTitle.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'PHẦN MỀM MARKETING',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, NavGroup group, bool isCollapsed) {
    final hasActiveItem = group.items.any((item) => currentRoute == item.routePath);

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
                color: hasActiveItem ? AppColors.primary : AppColors.textMuted,
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
            color: isActive ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusS),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusS),
              onTap: () => context.go(item.routePath),
              child: Center(
                child: Icon(
                  item.icon,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
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
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Stack(
        children: [
          // Nav item button body
          Material(
            color: isActive ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusS),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusS),
              onTap: () => context.go(item.routePath),
              child: Row(
                children: [
                  const SizedBox(width: AppSpacing.m),
                  Icon(
                    item.icon,
                    color: isActive ? AppColors.primary : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      item.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isActive ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Active left border line
          if (isActive)
            Positioned(
              left: 0,
              top: 8,
              bottom: 8,
              width: 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
