import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

class CampaignConfigCard extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initialExpanded;
  final List<Widget>? headerActions;

  const CampaignConfigCard({
    super.key,
    required this.title,
    required this.child,
    this.initialExpanded = true,
    this.headerActions,
  });

  @override
  State<CampaignConfigCard> createState() => _CampaignConfigCardState();
}

class _CampaignConfigCardState extends State<CampaignConfigCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF111827) : AppColors.surface;
    final borderColor = isDark ? const Color(0xFF253247) : AppColors.border;
    final textPrimaryColor = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.textPrimary;
    final textSecondaryColor = isDark
        ? Colors.white
        : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: borderColor, width: 1),
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppSpacing.radiusM),
              topRight: Radius.circular(AppSpacing.radiusM),
              bottomLeft: Radius.circular(_isExpanded ? 0 : AppSpacing.radiusM),
              bottomRight: Radius.circular(
                _isExpanded ? 0 : AppSpacing.radiusM,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: textSecondaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: textPrimaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.headerActions != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.headerActions!,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Collapsible Content
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: widget.child,
            ),
          ],
        ],
      ),
    );
  }
}
