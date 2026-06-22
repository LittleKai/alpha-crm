import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final bool hasBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.l),
    this.width,
    this.height,
    this.backgroundColor,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Resolve surface color if it's default null
    final resolvedBg =
        backgroundColor ?? (theme.cardTheme.color ?? theme.colorScheme.surface);

    final resolvedBorder = isDark ? const Color(0xFF253247) : AppColors.border;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: resolvedBg,
        borderRadius: AppSpacing.borderRadiusM,
        border: hasBorder ? Border.all(color: resolvedBorder, width: 1) : null,
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.02),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppSpacing.borderRadiusM,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
