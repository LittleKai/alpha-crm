import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/routing/app_routes.dart';
import '../../../messaging/live_chat/providers/live_chat_provider.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../providers/crm_tasks_provider.dart';

class CrmTasksScreen extends ConsumerWidget {
  const CrmTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(crmTasksProvider);
    final notifier = ref.read(crmTasksProvider.notifier);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppSpacing.borderRadiusS,
                  ),
                  child: Icon(
                    Icons.task_alt_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Công việc chăm sóc', style: AppTextStyles.pageTitle),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Theo dõi và xử lý kịp thời công việc từ khách hàng, nhóm Zalo và điểm cần chú ý từ CRM.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                IconButton(
                  icon: state.isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: 'Làm mới',
                  onPressed: state.isLoading ? null : notifier.loadTasks,
                ),
                const SizedBox(width: AppSpacing.s),
                AppButton(
                  text: 'Tạo công việc',
                  icon: Icons.add_rounded,
                  onPressed: () => _showTaskFormDialog(context, notifier),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            _StatusFilterBar(
              current: state.statusFilter,
              openCount: state.openCount,
              onChanged: notifier.setStatusFilter,
            ),
            const SizedBox(height: AppSpacing.m),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: Text(
                  state.errorMessage!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.errorText,
                  ),
                ),
              ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.tasks.isEmpty
                  ? const AppCard(
                      child: AppEmptyState(
                        icon: Icons.task_outlined,
                        title: 'Chưa có công việc nào',
                        description:
                            'Danh sách công việc giúp bạn chủ động chăm sóc khách hàng và xử lý phản hồi kịp thời.',
                        height: 420,
                      ),
                    )
                  : ListView.separated(
                      itemCount: state.tasks.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.s),
                      itemBuilder: (context, index) {
                        final task = state.tasks[index];
                        return _TaskCard(
                          task: task,
                          notifier: notifier,
                          onOpenLiveChat: task.hasGroupLink
                              ? () => _openLiveChat(context, ref, task)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showTaskFormDialog(
    BuildContext context,
    CrmTasksNotifier notifier, {
    CrmTask? task,
  }) async {
    final isEdit = task != null;
    final titleController = TextEditingController(text: task?.title ?? '');
    final descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    String priority = task?.priority ?? 'medium';
    DateTime? dueAt = task?.dueAt;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AppDialog(
              title: isEdit ? 'Sửa công việc' : 'Tạo công việc chăm sóc',
              icon: Icons.task_alt_rounded,
              width: 460,
              actions: [
                AppDialogAction(
                  text: 'Hủy',
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                AppDialogAction(
                  text: 'Lưu',
                  onPressed: () async {
                    if (isEdit) {
                      await notifier.updateTask(
                        task,
                        title: titleController.text,
                        description: descriptionController.text,
                        priority: priority,
                        dueAt: dueAt,
                      );
                    } else {
                      await notifier.createTask(
                        title: titleController.text,
                        description: descriptionController.text,
                        priority: priority,
                        dueAt: dueAt,
                      );
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề công việc',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả chi tiết',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(
                      labelText: 'Mức độ ưu tiên',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Thấp')),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Text('Trung bình'),
                      ),
                      DropdownMenuItem(value: 'high', child: Text('Cao')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => priority = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      dueAt == null
                          ? 'Hạn xử lý: tự động theo ưu tiên'
                          : 'Hạn: ${DateFormat('dd/MM/yyyy HH:mm').format(dueAt!)}',
                    ),
                    onPressed: () async {
                      final picked = await _pickDateTime(
                        context,
                        dueAt ?? defaultDueByPriority(priority),
                      );
                      if (picked != null) setState(() => dueAt = picked);
                    },
                  ),
                  if (!isEdit)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        'Để trống sẽ tự gán hạn: Cao +1 ngày, Trung bình +3 ngày, Thấp +7 ngày.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
  }

  static Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime initial,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    final t = time ?? TimeOfDay.fromDateTime(initial);
    return DateTime(date.year, date.month, date.day, t.hour, t.minute);
  }

  static void _openLiveChat(BuildContext context, WidgetRef ref, CrmTask task) {
    ref.read(liveChatDeepLinkProvider.notifier).state = LiveChatDeepLink(
      accountId: task.groupAccountId,
      threadId: task.groupThreadId,
    );
    context.go(AppRoutes.messagingLiveChat);
  }
}

class _StatusFilterBar extends StatelessWidget {
  final String current;
  final int openCount;
  final ValueChanged<String> onChanged;

  const _StatusFilterBar({
    required this.current,
    required this.openCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s,
      children: [
        _chip('open', 'Chưa làm', openCount),
        _chip('done', 'Đã hoàn thành', null),
        _chip('dismissed', 'Đã bỏ qua', null),
      ],
    );
  }

  Widget _chip(String value, String label, int? count) {
    final selected = current == value;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onChanged(value),
      selectedColor: AppColors.primarySoft,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count != null && count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      labelStyle: AppTextStyles.bodyMedium.copyWith(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final CrmTask task;
  final CrmTasksNotifier notifier;
  final VoidCallback? onOpenLiveChat;

  const _TaskCard({
    required this.task,
    required this.notifier,
    this.onOpenLiveChat,
  });

  @override
  Widget build(BuildContext context) {
    final type = _typeMeta(task.relatedType);
    final overdue =
        task.dueAt != null &&
        task.status == 'open' &&
        task.dueAt!.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.borderRadiusM,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: type.color.withValues(alpha: 0.12),
              borderRadius: AppSpacing.borderRadiusS,
            ),
            child: Icon(type.icon, color: type.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    decoration: task.status == 'done'
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.status == 'open'
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.description,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s),
                Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _PriorityBadge(priority: task.priority),
                    _MetaChip(icon: type.icon, label: type.label),
                    if (task.groupName.isNotEmpty)
                      _MetaChip(
                        icon: Icons.groups_outlined,
                        label: task.groupName,
                        color: const Color(0xFF0EA5E9),
                      ),
                    if (task.dueAt != null)
                      _MetaChip(
                        icon: Icons.schedule,
                        label: overdue
                            ? 'Quá hạn ${DateFormat('dd/MM HH:mm').format(task.dueAt!)}'
                            : 'Hạn ${DateFormat('dd/MM HH:mm').format(task.dueAt!)}',
                        color: overdue ? AppColors.error : null,
                      ),
                    if (onOpenLiveChat != null)
                      _LiveChatChip(onTap: onOpenLiveChat!),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          _TaskActions(task: task, notifier: notifier),
        ],
      ),
    );
  }

  _TypeMeta _typeMeta(String relatedType) {
    switch (relatedType) {
      case 'customer':
        return const _TypeMeta(
          Icons.person_outline,
          Color(0xFF2563EB),
          'Khách hàng',
        );
      case 'group':
        return const _TypeMeta(
          Icons.groups_outlined,
          Color(0xFF0EA5E9),
          'Nhóm Zalo',
        );
      case 'conversation':
        return const _TypeMeta(
          Icons.chat_bubble_outline,
          Color(0xFF8B5CF6),
          'Hội thoại',
        );
      case 'insight':
        return const _TypeMeta(
          Icons.lightbulb_outline,
          Color(0xFFF59E0B),
          'Điểm cần chú ý',
        );
      default:
        return const _TypeMeta(
          Icons.edit_note_outlined,
          Colors.white60,
          'Tự tạo',
        );
    }
  }
}

class _TaskActions extends StatelessWidget {
  final CrmTask task;
  final CrmTasksNotifier notifier;

  const _TaskActions({required this.task, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        if (task.status == 'open')
          IconButton(
            tooltip: 'Hoàn thành',
            icon: const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
            ),
            onPressed: () => notifier.updateStatus(task, 'done'),
          ),
        if (task.status == 'open')
          IconButton(
            tooltip: 'Bỏ qua',
            icon: const Icon(Icons.block_outlined, color: AppColors.warning),
            onPressed: () => notifier.updateStatus(task, 'dismissed'),
          ),
        if (task.status != 'open')
          IconButton(
            tooltip: 'Mở lại',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => notifier.updateStatus(task, 'open'),
          ),
        IconButton(
          tooltip: 'Sửa',
          icon: Icon(Icons.edit_outlined, color: AppColors.textSecondary),
          onPressed: () =>
              CrmTasksScreen._showTaskFormDialog(context, notifier, task: task),
        ),
        IconButton(
          tooltip: 'Xóa',
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: () => _confirmDelete(context),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Xóa công việc',
        icon: Icons.delete_outline,
        width: 440,
        actions: [
          AppDialogAction(
            text: 'Hủy',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppDialogAction(
            text: 'Xóa',
            variant: AppButtonVariant.destructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
        child: Text(
          'Xóa công việc "${task.title}"? Hành động này không thể hoàn tác.',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );
    if (confirmed == true) {
      await notifier.deleteTask(task);
    }
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetaChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: c,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveChatChip extends StatelessWidget {
  final VoidCallback onTap;

  const _LiveChatChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 14, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'Mở Live Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeMeta {
  final IconData icon;
  final Color color;
  final String label;

  const _TypeMeta(this.icon, this.color, this.label);
}

class _PriorityBadge extends StatelessWidget {
  final String priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    return switch (priority) {
      'high' => const AppBadge(label: 'Cao', variant: AppBadgeVariant.error),
      'low' => const AppBadge(label: 'Thấp', variant: AppBadgeVariant.neutral),
      _ => const AppBadge(label: 'Trung bình', variant: AppBadgeVariant.info),
    };
  }
}
