import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../../shared/widgets/app_select_field.dart';
import '../../../../settings/providers/settings_provider.dart';
import '../../providers/managed_groups_provider.dart';

/// Summary AI models the operator can pick for this tab. Keys must match the
/// backend `SUMMARY_ALLOWED_AI_MODELS` list.
const List<({String key, String label})> kSummaryModels = [
  (key: 'gemini-3.1-pro', label: 'Gemini 3.1 Pro (mặc định)'),
  (key: 'gemini-2.5-pro', label: 'Gemini 2.5 Pro'),
  (key: 'gemini-3-flash', label: 'Gemini 3 Flash'),
];

Future<void> showGroupSummarySettings(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _GroupSummarySettingsDialog(),
  );
}

class _GroupSummarySettingsDialog extends ConsumerStatefulWidget {
  const _GroupSummarySettingsDialog();

  @override
  ConsumerState<_GroupSummarySettingsDialog> createState() =>
      _GroupSummarySettingsDialogState();
}

class _GroupSummarySettingsDialogState
    extends ConsumerState<_GroupSummarySettingsDialog> {
  String _model = 'gemini-3.1-pro';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(managedGroupsRepositoryProvider);
    final res = await repo.getSummarySettings();
    if (!mounted) return;
    final data = res['data'];
    setState(() {
      _loading = false;
      if (res['success'] == true && data is Map) {
        final m = (data['aiModel'] ?? 'gemini-3.1-pro').toString();
        if (kSummaryModels.any((e) => e.key == m)) _model = m;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(managedGroupsRepositoryProvider);
    final res = await repo.saveSummaryModel(_model);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = (res['message'] ?? 'Lưu cấu hình thất bại.').toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Cài đặt tóm tắt',
      subtitle: 'Áp dụng cho mọi tóm tắt AI của nhóm.',
      icon: Icons.settings_outlined,
      width: 460,
      actions: [
        AppDialogAction(
          text: 'Hủy',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(
          text: 'Lưu',
          onPressed: _saving || _loading ? null : _save,
        ),
      ],
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.l),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Model AI tóm tắt', style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                AppSelectField<String>(
                  value: _model,
                  items: kSummaryModels
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.key,
                          child: Text(m.label),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _model = v);
                  },
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  'Model Pro cho chất lượng tóm tắt cao hơn nhưng tiêu hao 2 đơn vị quota mỗi lần; Flash tiêu hao 1 đơn vị.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Divider(color: AppColors.borderSoft),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: ref.watch(
                    settingsProvider.select(
                      (s) => s.settings.showTokenAnalytics,
                    ),
                  ),
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
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .updateShowTokenAnalytics(v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    _error!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.errorText,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
