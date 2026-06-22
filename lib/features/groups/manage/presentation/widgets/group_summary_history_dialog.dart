import 'package:flutter/material.dart';
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
    builder: (_) => AppDialog(
      title: 'Lịch sử tóm tắt',
      subtitle: groupName,
      icon: Icons.history,
      width: 640,
      actions: [
        AppDialogAction(
          text: 'Đóng',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: summaries.isEmpty
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
                  'Tổng cộng ${summaries.length} lần tóm tắt (lưu trên máy này).',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                ...summaries.map((s) => _HistoryEntry(summary: s)),
              ],
            ),
    ),
  );
}

class _HistoryEntry extends StatelessWidget {
  final GroupSummaryRecord summary;

  const _HistoryEntry({required this.summary});

  @override
  Widget build(BuildContext context) {
    final header = StringBuffer(
      DateFormat('dd/MM/yyyy HH:mm').format(summary.createdAt),
    );
    if (summary.messageCount > 0) {
      header.write(' · ${summary.messageCount} tin');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.borderRadiusS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header.toString(),
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          if (summary.summaryText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(summary.summaryText, style: AppTextStyles.body),
          ],
          _section('Lead nóng / quan tâm', summary.opportunities),
          _section('Câu hỏi chưa trả lời', summary.questions),
          _section('Phàn nàn / rủi ro', summary.risks),
          _section('Chủ đề nổi bật', summary.keyTopics),
          _section('Quyết định', summary.decisions),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: AppSpacing.m, bottom: 2),
              child: Text('• $item', style: AppTextStyles.body),
            ),
          ),
        ],
      ),
    );
  }
}
