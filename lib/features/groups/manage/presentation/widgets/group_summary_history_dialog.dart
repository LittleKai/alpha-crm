import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../providers/managed_groups_provider.dart';

/// Full, detailed history of every AI summary made for a group (local data).
Future<void> showGroupSummaryHistory(
  BuildContext context, {
  required String groupName,
  required List<GroupSummaryRecord> summaries,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(managedGroupsProvider);
        final currentSummaries = state.selectedSummaries;

        return AppDialog(
          title: 'Lịch sử tóm tắt',
          subtitle: groupName,
          icon: Icons.history,
          width: 640,
          actions: [
            AppDialogAction(
              text: 'Đóng',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
          child: currentSummaries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
                  child: Text(
                    'Chưa có tóm tắt nào cho nhóm này.',
                    style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tổng cộng ${currentSummaries.length} lần tóm tắt (lưu trên máy này).',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    ...currentSummaries.map((s) => _HistoryEntry(
                          summary: s,
                          onDelete: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (confirmContext) => AppDialog(
                                title: 'Xác nhận xóa',
                                subtitle: 'Xóa bản tóm tắt này khỏi cơ sở dữ liệu?',
                                icon: Icons.warning_amber_rounded,
                                actions: [
                                  AppDialogAction(
                                    text: 'Hủy',
                                    variant: AppButtonVariant.outline,
                                    onPressed: () => Navigator.of(confirmContext).pop(false),
                                  ),
                                  AppDialogAction(
                                    text: 'Xóa',
                                    variant: AppButtonVariant.destructive,
                                    onPressed: () => Navigator.of(confirmContext).pop(true),
                                  ),
                                ],
                                child: Text(
                                  'Hành động này không thể hoàn tác.',
                                  style: AppTextStyles.body,
                                ),
                              ),
                            );

                            if (confirm == true) {
                              await ref.read(managedGroupsProvider.notifier).deleteSummary(s.id);
                            }
                          },
                        )),
                  ],
                ),
        );
      },
    ),
  );
}

class _HistoryEntry extends StatefulWidget {
  final GroupSummaryRecord summary;
  final VoidCallback onDelete;

  const _HistoryEntry({
    required this.summary,
    required this.onDelete,
  });

  @override
  State<_HistoryEntry> createState() => _HistoryEntryState();
}

class _HistoryEntryState extends State<_HistoryEntry> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final header = StringBuffer(
      DateFormat('dd/MM/yyyy HH:mm').format(widget.summary.createdAt),
    );
    if (widget.summary.messageCount > 0) {
      header.write(' · ${widget.summary.messageCount} tin');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.borderRadiusS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: AppSpacing.borderRadiusS,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      header.toString(),
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    tooltip: 'Xóa bản tóm tắt',
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.m,
                right: AppSpacing.m,
                bottom: AppSpacing.m,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  if (widget.summary.summaryText.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.summary.summaryText,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  _section(
                    'Lead nóng / quan tâm',
                    widget.summary.opportunities,
                    color: Colors.red[700],
                  ),
                  _section(
                    'Câu hỏi chưa trả lời',
                    widget.summary.questions,
                    color: Colors.orange[700],
                  ),
                  _section(
                    'Phàn nàn / rủi ro',
                    widget.summary.risks,
                    color: Colors.red[800],
                  ),
                  _section(
                    'Chủ đề nổi bật',
                    widget.summary.keyTopics,
                    color: AppColors.primary,
                  ),
                  _section(
                    'Quyết định',
                    widget.summary.decisions,
                    color: Colors.green[700],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items, {Color? color}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: AppSpacing.m, bottom: 2),
              child: Text(
                '• $item',
                style: AppTextStyles.body.copyWith(
                  color: color != null ? color.withOpacity(0.9) : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
