import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/widgets/app_badge.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../providers/managed_groups_provider.dart';

/// Shows extracted action items for review before creating follow-up tasks.
/// Returns the items the operator chose to turn into tasks (empty/null = none).
Future<List<GroupInsight>?> showActionItemsPreview(
  BuildContext context, {
  required List<GroupInsight> items,
}) {
  return showDialog<List<GroupInsight>>(
    context: context,
    builder: (_) => _ActionItemsPreviewDialog(items: items),
  );
}

class _ActionItemsPreviewDialog extends StatefulWidget {
  final List<GroupInsight> items;

  const _ActionItemsPreviewDialog({required this.items});

  @override
  State<_ActionItemsPreviewDialog> createState() =>
      _ActionItemsPreviewDialogState();
}

class _ActionItemsPreviewDialogState extends State<_ActionItemsPreviewDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.items.map((e) => e.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Việc cần làm từ tóm tắt',
      subtitle: 'Chọn các mục để tạo công việc follow-up.',
      icon: Icons.checklist_outlined,
      width: 560,
      actions: [
        AppDialogAction(
          text: 'Bỏ qua',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(
          text: 'Tạo ${_selected.length} công việc',
          icon: Icons.add_task_outlined,
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  widget.items
                      .where((e) => _selected.contains(e.id))
                      .toList(),
                ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.items.map((item) {
          final checked = _selected.contains(item.id);
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: AppSpacing.borderRadiusS,
            ),
            child: CheckboxListTile(
              value: checked,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selected.add(item.id);
                } else {
                  _selected.remove(item.id);
                }
              }),
              title: Row(
                children: [
                  Expanded(
                    child: Text(item.title, style: AppTextStyles.bodyMedium),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  AppBadge(
                    label: _priorityLabel(item.priority),
                    variant: _priorityVariant(item.priority),
                  ),
                ],
              ),
              subtitle: item.description.isEmpty
                  ? null
                  : Text(
                      item.description,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return 'Cao';
      case 'low':
        return 'Thấp';
      default:
        return 'Vừa';
    }
  }

  AppBadgeVariant _priorityVariant(String priority) {
    switch (priority) {
      case 'high':
        return AppBadgeVariant.error;
      case 'low':
        return AppBadgeVariant.neutral;
      default:
        return AppBadgeVariant.warning;
    }
  }
}
