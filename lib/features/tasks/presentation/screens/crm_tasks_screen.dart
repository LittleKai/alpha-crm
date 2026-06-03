import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../providers/crm_tasks_provider.dart';

class CrmTasksScreen extends ConsumerWidget {
  const CrmTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(crmTasksProvider);
    final notifier = ref.read(crmTasksProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.task_alt_outlined,
                  color: AppColors.primary,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Công việc follow-up',
                        style: AppTextStyles.pageTitle,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Theo dõi và quản lý công việc cần làm từ khách hàng, nhóm Zalo và insight CRM.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownButton<String>(
                  value: state.statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Chưa làm')),
                    DropdownMenuItem(
                      value: 'done',
                      child: Text('Đã hoàn thành'),
                    ),
                    DropdownMenuItem(
                      value: 'dismissed',
                      child: Text('Đã bỏ qua'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) notifier.setStatusFilter(value);
                  },
                ),
                const SizedBox(width: AppSpacing.s),
                AppButton(
                  text: 'Tạo công việc',
                  icon: Icons.add_rounded,
                  onPressed: () => _showCreateTaskDialog(context, notifier),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            if (state.errorMessage != null)
              Text(
                state.errorMessage!,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.errorText,
                ),
              ),
            Expanded(
              child: AppCard(
                padding: EdgeInsets.zero,
                child: state.tasks.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.task_outlined,
                        title: 'Chưa có công việc nào',
                        description:
                            'Danh sách công việc cần làm giúp bạn chủ động chăm sóc khách hàng và xử lý các phản hồi CRM kịp thời.',
                        height: 420,
                      )
                    : ListView.separated(
                        itemCount: state.tasks.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final task = state.tasks[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.m,
                              vertical: AppSpacing.s,
                            ),
                            leading: _PriorityBadge(priority: task.priority),
                            title: Text(
                              task.title,
                              style: AppTextStyles.bodyMedium,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (task.description.isNotEmpty)
                                  Text(task.description),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    task.relatedType,
                                    if (task.dueAt != null)
                                      'Hạn chót: ${DateFormat('dd/MM/yyyy HH:mm').format(task.dueAt!)}',
                                  ].join(' - '),
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Wrap(
                              spacing: AppSpacing.xs,
                              children: [
                                if (task.status == 'open')
                                  IconButton(
                                    tooltip: 'Done',
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                    ),
                                    onPressed: () =>
                                        notifier.updateStatus(task, 'done'),
                                  ),
                                if (task.status == 'open')
                                  IconButton(
                                    tooltip: 'Dismiss',
                                    icon: const Icon(Icons.block_outlined),
                                    onPressed: () => notifier.updateStatus(
                                      task,
                                      'dismissed',
                                    ),
                                  ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () => notifier.deleteTask(task),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateTaskDialog(
    BuildContext context,
    CrmTasksNotifier notifier,
  ) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String priority = 'medium';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Tạo công việc follow-up'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      minLines: 3,
                      maxLines: 5,
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await notifier.createTask(
                      title: titleController.text,
                      description: descriptionController.text,
                      priority: priority,
                    );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
  }
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
