import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../../shared/widgets/app_select_field.dart';
import '../../../../settings/providers/settings_provider.dart';

/// Summary AI models the operator can pick. Keys must match the backend
/// `SUMMARY_ALLOWED_AI_MODELS` list. Stored as a LOCAL setting and sent with
/// each summarize request — no cloud round-trip.
const List<({String key, String label, String desc})> kSummaryModels = [
  (key: 'gemini-3.1-pro', label: 'Gemini 3.1 Pro (mặc định)', desc: 'Chất lượng cao nhất, tiêu hao 2 quota/lần'),
  (key: 'gemini-3.5-flash', label: 'Gemini 3.5 Flash', desc: 'Tốc độ cực nhanh, tiêu hao 2 quota/lần'),
  (key: 'gemini-3-flash', label: 'Gemini 3 Flash', desc: 'Cơ bản, tiêu hao 1 quota/lần'),
];

Future<void> showGroupSummarySettings(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _GroupSummarySettingsDialog(),
  );
}

class _GroupSummarySettingsDialog extends ConsumerWidget {
  const _GroupSummarySettingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).settings;
    final notifier = ref.read(settingsProvider.notifier);
    final model = kSummaryModels.any((e) => e.key == settings.summaryAiModel)
        ? settings.summaryAiModel
        : 'gemini-3.1-pro';

    return AppDialog(
      title: 'Cài đặt tóm tắt',
      subtitle: 'Áp dụng cho mọi tóm tắt AI của nhóm (lưu trên máy này).',
      icon: Icons.settings_outlined,
      width: 460,
      actions: [
        AppDialogAction(
          text: 'Đóng',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Model AI tóm tắt', style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          AppSelectField<String>(
            value: model,
            itemHeight: 56,
            selectedItemBuilder: (BuildContext context) {
              return kSummaryModels.map<Widget>((m) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    m.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              }).toList();
            },
            items: kSummaryModels
                .map(
                  (m) =>
                      DropdownMenuItem(
                        value: m.key, 
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(m.desc, style: TextStyle(fontSize: 12, color: AppColors.primary)),
                          ],
                        ),
                      ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) notifier.updateSummaryAiModel(v);
            },
          ),
          const SizedBox(height: AppSpacing.s),
          Divider(color: AppColors.borderSoft),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: settings.showTokenAnalytics,
            title: Text(
              'Hiện thống kê token in/out',
              style: AppTextStyles.body,
            ),
            subtitle: Text(
              'Cột token trong Nhật ký phản hồi + biểu đồ ở Tổng quan chiến dịch.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            onChanged: notifier.updateShowTokenAnalytics,
          ),
        ],
      ),
    );
  }
}
