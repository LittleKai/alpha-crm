import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme_tokens.dart';

class ViewFilterChipItem {
  final String id;
  final String label;
  final String value;
  final IconData icon;
  final bool isDanger;
  final VoidCallback onRemove;

  const ViewFilterChipItem({
    required this.id,
    required this.label,
    required this.value,
    required this.icon,
    this.isDanger = false,
    required this.onRemove,
  });
}

/// Reusable collapsible filter/sort chip strip modeled on Twenty's
/// `ViewBarDetails` + `SortOrFilterChip`. Never uses `Spacer` or `Expanded`
/// directly inside `Wrap` (per Alpha CRM guard #1).
class ViewChipBar extends StatelessWidget {
  final List<ViewFilterChipItem> chips;
  final VoidCallback? onReset;
  final VoidCallback? onSaveSegment;
  final String saveSegmentLabel;

  const ViewChipBar({
    super.key,
    required this.chips,
    this.onReset,
    this.onSaveSegment,
    this.saveSegmentLabel = 'Lưu segment',
  });

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    final tokens = AppThemeTokens.of(context);

    return Container(
      key: const ValueKey('view_chip_bar'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderMedium, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: chips.map((chip) => _FilterChipPill(chip: chip)).toList(),
            ),
          ),
          if (onReset != null || onSaveSegment != null) ...[
            const SizedBox(width: AppSpacing.s),
            Container(width: 1, height: 18, color: tokens.borderMedium),
            const SizedBox(width: AppSpacing.xs),
            if (onReset != null)
              TextButton(
                key: const ValueKey('view_chip_reset_button'),
                style: TextButton.styleFrom(
                  foregroundColor: tokens.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 26),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onReset,
                child: const Text(
                  'Đặt lại',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            if (onSaveSegment != null) ...[
              const SizedBox(width: 4),
              TextButton.icon(
                key: const ValueKey('view_chip_save_segment'),
                style: TextButton.styleFrom(
                  foregroundColor: tokens.accentBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 26),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onSaveSegment,
                icon: const Icon(Icons.bookmark_add_outlined, size: 14),
                label: Text(
                  saveSegmentLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  final ViewFilterChipItem chip;

  const _FilterChipPill({required this.chip});

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final Color bg = chip.isDanger ? tokens.dangerBg : tokens.surfacePrimary;
    final Color fg = chip.isDanger ? tokens.dangerText : tokens.textPrimary;
    final Color muted = chip.isDanger
        ? tokens.dangerText
        : tokens.textSecondary;
    final Color borderColor =
        chip.isDanger ? tokens.dangerText.withValues(alpha: 0.3) : tokens.borderMedium;

    return Container(
      height: 26,
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, size: 13, color: muted),
          const SizedBox(width: 5),
          Text(
            '${chip.label}: ',
            style: TextStyle(
              fontSize: 12,
              color: muted,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            chip.value,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            key: ValueKey('view_chip_remove_${chip.id}'),
            borderRadius: BorderRadius.circular(4),
            onTap: chip.onRemove,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close, size: 13, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
