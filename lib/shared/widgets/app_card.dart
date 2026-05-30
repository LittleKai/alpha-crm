import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final Color backgroundColor;
  final bool hasBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.l),
    this.width,
    this.height,
    this.backgroundColor = AppColors.surface,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppSpacing.borderRadiusM,
        border: hasBorder
            ? Border.all(color: AppColors.border, width: 1)
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.02),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}
