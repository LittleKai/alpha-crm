import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../../shared/widgets/app_select_field.dart';
import '../../data/group_summary_templates.dart';
import '../../providers/managed_groups_provider.dart';

/// Shows the AI summary configuration wizard. Returns the chosen config, or
/// null if cancelled.
Future<GroupSummaryConfig?> showGroupSummaryWizard(
  BuildContext context, {
  required String groupName,
  GroupSummaryConfig? initial,
  Future<int> Function(GroupSummaryConfig)? previewCount,
}) {
  return showDialog<GroupSummaryConfig>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _GroupSummaryWizard(
      groupName: groupName,
      initial: initial ?? const GroupSummaryConfig(),
      previewCount: previewCount,
    ),
  );
}

class _GroupSummaryWizard extends StatefulWidget {
  final String groupName;
  final GroupSummaryConfig initial;
  final Future<int> Function(GroupSummaryConfig)? previewCount;

  const _GroupSummaryWizard({
    required this.groupName,
    required this.initial,
    this.previewCount,
  });

  @override
  State<_GroupSummaryWizard> createState() => _GroupSummaryWizardState();
}

class _GroupSummaryWizardState extends State<_GroupSummaryWizard> {
  late String _scopeMode;
  late int _recentCount;
  late int _rangeDays;
  late Set<String> _goals;
  late String _industry;
  late bool _autoCreateTasks;
  late final TextEditingController _promptController;

  /// Available local messages for the current scope; null = not yet loaded,
  /// -1 = local store unreachable (don't block on it).
  int? _availableCount;
  bool _countLoading = false;
  int _countRequestId = 0;

  bool get _blocked =>
      _availableCount != null &&
      _availableCount! >= 0 &&
      _availableCount! < kMinSummaryMessages;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _scopeMode = c.scopeMode;
    _recentCount = c.recentCount;
    _rangeDays = c.rangeDays;
    _goals = {...c.goals};
    _industry = c.industry;
    _autoCreateTasks = c.autoCreateTasks;
    _promptController = TextEditingController(
      text: c.prompt.isNotEmpty
          ? c.prompt
          : industryTemplateByKey(c.industry).prompt,
    );
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    if (widget.previewCount == null) return;
    final reqId = ++_countRequestId;
    setState(() => _countLoading = true);
    final count = await widget.previewCount!(_buildConfig());
    if (!mounted || reqId != _countRequestId) return;
    setState(() {
      _countLoading = false;
      _availableCount = count;
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _applyIndustry(String key) {
    setState(() {
      _industry = key;
      _promptController.text = industryTemplateByKey(key).prompt;
    });
  }

  GroupSummaryConfig _buildConfig() {
    return GroupSummaryConfig(
      scopeMode: _scopeMode,
      recentCount: _recentCount,
      rangeDays: _rangeDays,
      goals: _goals.isEmpty ? {'actions'} : _goals,
      industry: _industry,
      prompt: _promptController.text.trim(),
      autoCreateTasks: _autoCreateTasks,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Cấu hình tóm tắt AI',
      subtitle: widget.groupName,
      icon: Icons.auto_awesome_outlined,
      width: 620,
      actions: [
        AppDialogAction(
          text: 'Hủy',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(
          text: 'Tóm tắt',
          icon: Icons.summarize_outlined,
          onPressed: _blocked
              ? null
              : () => Navigator.of(context).pop(_buildConfig()),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Phạm vi tóm tắt'),
          _ScopeSelector(
            mode: _scopeMode,
            recentCount: _recentCount,
            rangeDays: _rangeDays,
            onModeChanged: (m) {
              setState(() => _scopeMode = m);
              _refreshCount();
            },
            onRecentCountChanged: (v) {
              setState(() => _recentCount = v);
              _refreshCount();
            },
            onRangeDaysChanged: (v) {
              setState(() => _rangeDays = v);
              _refreshCount();
            },
          ),
          if (widget.previewCount != null) ...[
            const SizedBox(height: AppSpacing.s),
            _CountHint(
              loading: _countLoading,
              count: _availableCount,
              blocked: _blocked,
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          _label('Mục tiêu trích xuất'),
          ...kSummaryGoals.map(
            (goal) => CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _goals.contains(goal.key),
              title: Text(goal.label, style: AppTextStyles.body),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _goals.add(goal.key);
                } else {
                  _goals.remove(goal.key);
                }
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          _label('Mẫu prompt theo ngành'),
          AppSelectField<String>(
            value: _industry,
            items: kIndustryTemplates
                .map(
                  (t) => DropdownMenuItem(value: t.key, child: Text(t.label)),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) _applyIndustry(v);
            },
          ),
          const SizedBox(height: AppSpacing.s),
          _label('Nội dung prompt (có thể chỉnh sửa)'),
          TextField(
            controller: _promptController,
            maxLines: 5,
            minLines: 3,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: AppSpacing.borderRadiusS,
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppSpacing.borderRadiusS,
                borderSide: BorderSide(color: AppColors.border),
              ),
              contentPadding: const EdgeInsets.all(AppSpacing.s),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _autoCreateTasks,
            title: Text(
              'Tự đề xuất tạo công việc chăm sóc',
              style: AppTextStyles.body,
            ),
            subtitle: Text(
              'Sau khi tóm tắt sẽ hiện danh sách việc cần làm để bạn duyệt.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
            onChanged: (v) => setState(() => _autoCreateTasks = v),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: AppTextStyles.bodyMedium),
    );
  }
}

class _ScopeSelector extends StatelessWidget {
  final String mode;
  final int recentCount;
  final int rangeDays;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<int> onRecentCountChanged;
  final ValueChanged<int> onRangeDaysChanged;

  const _ScopeSelector({
    required this.mode,
    required this.recentCount,
    required this.rangeDays,
    required this.onModeChanged,
    required this.onRecentCountChanged,
    required this.onRangeDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.s,
          children: [
            _chip('Tiếp tục từ lần trước', 'incremental'),
            _chip('N tin gần nhất', 'recent'),
            _chip('Khoảng thời gian', 'range'),
          ],
        ),
        if (mode == 'recent') ...[
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            width: 200,
            child: AppSelectField<int>(
              value: recentCount,
              items: const [
                DropdownMenuItem(value: 50, child: Text('50 tin gần nhất')),
                DropdownMenuItem(value: 100, child: Text('100 tin gần nhất')),
                DropdownMenuItem(value: 200, child: Text('200 tin gần nhất')),
              ],
              onChanged: (v) {
                if (v != null) onRecentCountChanged(v);
              },
            ),
          ),
        ],
        if (mode == 'range') ...[
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            width: 200,
            child: AppSelectField<int>(
              value: rangeDays,
              items: const [
                DropdownMenuItem(value: 1, child: Text('Hôm nay')),
                DropdownMenuItem(value: 7, child: Text('7 ngày qua')),
                DropdownMenuItem(value: 30, child: Text('30 ngày qua')),
              ],
              onChanged: (v) {
                if (v != null) onRangeDaysChanged(v);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _chip(String label, String value) {
    final selected = mode == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onModeChanged(value),
      selectedColor: AppColors.primarySoft,
      labelStyle: AppTextStyles.caption.copyWith(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

/// Shows how many local messages the current scope covers, and warns when there
/// are fewer than [kMinSummaryMessages].
class _CountHint extends StatelessWidget {
  final bool loading;
  final int? count;
  final bool blocked;

  const _CountHint({
    required this.loading,
    required this.count,
    required this.blocked,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String text;

    if (loading) {
      icon = Icons.hourglass_empty;
      color = AppColors.textMuted;
      text = 'Đang đếm tin nhắn khả dụng...';
    } else if (count == null || count! < 0) {
      icon = Icons.help_outline;
      color = AppColors.textMuted;
      text = 'Không đọc được tin nhắn từ máy (cần bản desktop có backend local).';
    } else if (blocked) {
      icon = Icons.warning_amber_rounded;
      color = AppColors.warning;
      text =
          'Chỉ có $count tin nhắn — cần tối thiểu $kMinSummaryMessages tin để tóm tắt.';
    } else {
      icon = Icons.chat_bubble_outline;
      color = AppColors.primary;
      text = '≈ $count tin nhắn sẽ được tóm tắt.';
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
