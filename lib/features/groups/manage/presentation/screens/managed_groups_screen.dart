import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_badge.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/app_empty_state.dart';
import '../../../../../shared/widgets/app_select_field.dart';
import '../../../../../shared/widgets/compliance_warnings_popup.dart';
import '../../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../providers/managed_groups_provider.dart';
import '../widgets/action_items_preview_dialog.dart';
import '../widgets/group_summary_wizard_dialog.dart';

class ManagedGroupsScreen extends ConsumerWidget {
  const ManagedGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(managedGroupsProvider);
    final notifier = ref.read(managedGroupsProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(state: state, notifier: notifier),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: isMobile
                  ? Column(
                      children: [
                        Expanded(
                          child: _GroupsList(state: state, notifier: notifier),
                        ),
                        const SizedBox(height: AppSpacing.m),
                        Expanded(
                          child: _DetailsPanel(
                            state: state,
                            notifier: notifier,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 4,
                          child: _GroupsList(state: state, notifier: notifier),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          flex: 5,
                          child: _DetailsPanel(
                            state: state,
                            notifier: notifier,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final ManagedGroupsState state;
  final ManagedGroupsNotifier notifier;

  const _Header({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zaloState = ref.watch(zaloIntegrationProvider);
    final connectedAccounts = zaloState.accounts;
    final String activeId = state.selectedAccountId;

    return Row(
      children: [
        const Icon(Icons.groups_2_outlined, color: AppColors.primary, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quản lý nhóm Zalo', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Bật quản lý nhóm, tạo tóm tắt AI và theo dõi điểm cần chú ý khi vận hành.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        SizedBox(
          width: 240,
          child: AppSelectField<String>(
            value: activeId,
            hintText: 'Chọn tài khoản...',
            items: [
              DropdownMenuItem(
                value: '',
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primarySoft,
                      child: const Icon(
                        Icons.group_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        'Tất cả tài khoản',
                        style: AppTextStyles.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              ...connectedAccounts.map((account) {
                final cleanLabel = account.label.replaceAll(
                  RegExp(r'\s*\([^)]*\)$'),
                  '',
                );
                final avatarUrl = account.avatarUrl;

                return DropdownMenuItem(
                  value: account.id,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.surfaceMuted,
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                cleanLabel.isNotEmpty
                                    ? cleanLabel[0].toUpperCase()
                                    : 'A',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(
                          cleanLabel,
                          style: AppTextStyles.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            onChanged: (val) {
              if (val != null) {
                notifier.setSelectedAccountId(val);
              }
            },
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        Row(
          children: [
            Text('Chỉ nhóm quản lý', style: AppTextStyles.caption),
            Switch(
              value: state.showManagedOnly,
              onChanged: notifier.toggleManagedOnly,
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.s),
        IconButton(
          tooltip: 'Khuyến cáo an toàn',
          icon: const Icon(
            Icons.shield_outlined,
            color: AppColors.warning,
          ),
          onPressed: () => showComplianceWarningsDialog(
            context,
            actionType: ZaloActionType.scanGroupMembers,
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        AppButton(
          text: 'Đồng bộ',
          icon: Icons.sync,
          isLoading: state.isWorking,
          onPressed: state.isWorking ? null : notifier.syncGroups,
        ),
      ],
    );
  }
}

class _GroupsList extends ConsumerWidget {
  final ManagedGroupsState state;
  final ManagedGroupsNotifier notifier;

  const _GroupsList({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectedAccounts = ref.watch(zaloIntegrationProvider).accounts;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s),
      child: state.groups.isEmpty
          ? AppEmptyState(
              icon: Icons.groups_outlined,
              title: 'Chưa có nhóm',
              description:
                  state.errorMessage ??
                  'Bấm Đồng bộ để hệ thống tải danh sách nhóm Zalo.',
              height: 360,
            )
          : Builder(
              builder: (context) {
                final mergedGroupsMap = <String, ManagedZaloGroup>{};
                final groupAccountsMap = <String, List<ZaloConnectedAccount>>{};
                
                for (final group in state.groups) {
                  final gid = group.groupId;
                  if (!mergedGroupsMap.containsKey(gid)) {
                    mergedGroupsMap[gid] = group;
                    groupAccountsMap[gid] = [];
                  }
                  
                  ZaloConnectedAccount account;
                  try {
                    account = connectedAccounts.firstWhere((a) => a.id == group.accountId);
                  } catch (_) {
                    account = ZaloConnectedAccount(
                      id: group.accountId,
                      label: group.accountId,
                      connected: false,
                      listenerRunning: false,
                      avatarUrl: '',
                    );
                  }
                  
                  if (!groupAccountsMap[gid]!.any((a) => a.id == account.id)) {
                    groupAccountsMap[gid]!.add(account);
                  }
                }
                
                final mergedGroups = mergedGroupsMap.values.toList();

                return ListView.separated(
                  itemCount: mergedGroups.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final group = mergedGroups[index];
                    final accounts = groupAccountsMap[group.groupId] ?? [];
                    final selected = group.groupId == state.selectedGroup?.groupId;
                    final hasAvatar =
                        group.avatarUrl.isNotEmpty &&
                        group.avatarUrl.startsWith('http');
                    
                    final cleanName = group.name.replaceFirst(RegExp(r'^\[.*?\]\s*'), '');

                    return ListTile(
                      selected: selected,
                      selectedTileColor: AppColors.primarySoft,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceMuted,
                        backgroundImage: hasAvatar
                            ? NetworkImage(group.avatarUrl)
                            : null,
                        child: !hasAvatar
                            ? const Icon(Icons.groups_outlined)
                            : null,
                      ),
                      title: Text(
                        cleanName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          Text('${group.memberCount} thành viên - '),
                          ...accounts.map((acc) {
                            final accCleanName = acc.label.replaceAll(RegExp(r'\s*\([^)]*\)$'), '');
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (acc.avatarUrl.isNotEmpty)
                                  CircleAvatar(
                                    radius: 7,
                                    backgroundImage: NetworkImage(acc.avatarUrl),
                                  )
                                else
                                  const Icon(Icons.account_circle, size: 14),
                                const SizedBox(width: 4),
                                Text(accCleanName, style: const TextStyle(fontSize: 12)),
                              ],
                            );
                          }),
                        ],
                      ),
                      trailing: Switch(
                        value: group.isManaged,
                        onChanged: (value) => notifier.setManaged(group, value),
                      ),
                      onTap: () => notifier.selectGroup(group),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  final ManagedGroupsState state;
  final ManagedGroupsNotifier notifier;

  const _DetailsPanel({required this.state, required this.notifier});

  Future<void> _summarizeFlow(
    BuildContext context, {
    required bool forceWizard,
  }) async {
    final group = state.selectedGroup;
    if (group == null) return;
    final saved = GroupSummaryConfig.fromJson(group.summaryConfig);

    GroupSummaryConfig config;
    if (forceWizard || saved == null) {
      final picked = await showGroupSummaryWizard(
        context,
        groupName: group.name,
        initial: saved,
      );
      if (picked == null) return;
      config = picked;
    } else {
      config = saved;
    }

    final outcome = await notifier.summarizeWithConfig(config);
    if (!context.mounted || !outcome.success) return;

    if (outcome.empty) {
      _notify(context, 'Không có tin nhắn mới để tóm tắt.');
      return;
    }
    _notify(
      context,
      'Đã tóm tắt ${outcome.messageCount} tin · ${outcome.leadCount} lead · '
      '${outcome.questionCount} câu hỏi · ${outcome.actionItems.length} việc cần làm.',
    );

    if (config.autoCreateTasks && outcome.actionItems.isNotEmpty) {
      await _previewAndCreate(context, outcome.actionItems);
    }
  }

  Future<void> _previewAndCreate(
    BuildContext context,
    List<GroupInsight> items,
  ) async {
    final selected = await showActionItemsPreview(context, items: items);
    if (selected == null || selected.isEmpty || !context.mounted) return;
    final created = await notifier.createTasksFromInsights(selected);
    if (context.mounted) {
      _notify(context, 'Đã tạo $created công việc chăm sóc.');
    }
  }

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = state.selectedGroup;
    if (group == null) {
      return AppCard(
        child: Column(
          children: [
            const AppEmptyState(
              icon: Icons.manage_search_outlined,
              title: 'Chọn nhóm để quản lý',
              description:
                  'Tóm tắt, điểm cần chú ý và xuất file sẽ hiển thị tại đây.',
              height: 260,
            ),
            _InsightsList(insights: state.insights),
          ],
        ),
      );
    }

    final latest = state.selectedSummaries.isNotEmpty
        ? state.selectedSummaries.first
        : null;
    final older = state.selectedSummaries.length > 1
        ? state.selectedSummaries.sublist(1)
        : const <GroupSummaryRecord>[];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.s,
                      children: [
                        AppBadge(
                          label: group.isManaged
                              ? 'Đã quản lý'
                              : 'Chưa quản lý',
                          variant: group.isManaged
                              ? AppBadgeVariant.success
                              : AppBadgeVariant.neutral,
                        ),
                        AppBadge(
                          label: group.summaryCadence == 'daily'
                              ? 'Hàng ngày'
                              : (group.summaryCadence == 'weekly'
                                    ? 'Hàng tuần'
                                    : 'Thủ công'),
                          variant: AppBadgeVariant.info,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cấu hình tóm tắt',
                icon: const Icon(Icons.tune, color: AppColors.primary),
                onPressed: group.isManaged && !state.isWorking
                    ? () => _summarizeFlow(context, forceWizard: true)
                    : null,
              ),
              AppButton(
                text: 'Tóm tắt AI',
                icon: Icons.summarize_outlined,
                isLoading: state.isWorking,
                onPressed: group.isManaged && !state.isWorking
                    ? () => _summarizeFlow(context, forceWizard: false)
                    : null,
              ),
              const SizedBox(width: AppSpacing.s),
              AppButton(
                text: 'Xuất CSV',
                icon: Icons.download_outlined,
                variant: AppButtonVariant.outline,
                onPressed: notifier.exportSummaries,
              ),
            ],
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.s),
            Text(
              state.errorMessage!,
              style: AppTextStyles.caption.copyWith(color: AppColors.errorText),
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          Expanded(
            child: ListView(
              children: [
                if (state.proposedActionItems.isNotEmpty)
                  _ProposedActionsBanner(
                    count: state.proposedActionItems.length,
                    onReview: () => _previewAndCreate(
                      context,
                      state.proposedActionItems,
                    ),
                  ),
                Text('Tóm tắt mới nhất', style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.s),
                if (latest == null)
                  Text(
                    'Chưa có tóm tắt cho nhóm này.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                  )
                else
                  _StructuredSummaryView(summary: latest),
                if (older.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.m),
                  Text('Tóm tắt trước đó', style: AppTextStyles.bodyMedium),
                  const SizedBox(height: AppSpacing.s),
                  ...older.map(
                    (summary) => Container(
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
                            DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(summary.createdAt),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(summary.summaryText, style: AppTextStyles.body),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.m),
                _InsightsList(insights: state.insights),
                if (state.exportCsv != null && state.exportCsv!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    'Xem trước xuất dữ liệu CSV',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  SelectableText(
                    state.exportCsv!,
                    maxLines: 8,
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposedActionsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onReview;

  const _ProposedActionsBanner({required this.count, required this.onReview});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppSpacing.borderRadiusS,
      ),
      child: Row(
        children: [
          const Icon(Icons.checklist_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              '$count việc cần làm được trích xuất. Duyệt để tạo công việc chăm sóc.',
              style: AppTextStyles.body,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          AppButton(
            text: 'Tạo công việc',
            icon: Icons.add_task_outlined,
            onPressed: onReview,
          ),
        ],
      ),
    );
  }
}

class _StructuredSummaryView extends StatelessWidget {
  final GroupSummaryRecord summary;

  const _StructuredSummaryView({required this.summary});

  @override
  Widget build(BuildContext context) {
    final coverage = StringBuffer(
      DateFormat('dd/MM/yyyy HH:mm').format(summary.createdAt),
    );
    if (summary.messageCount > 0) {
      coverage.write(' · ${summary.messageCount} tin');
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.borderRadiusS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            coverage.toString(),
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (summary.summaryText.isNotEmpty)
            Text(summary.summaryText, style: AppTextStyles.body),
          _section(
            'Lead nóng / quan tâm',
            summary.opportunities,
            Icons.local_fire_department_outlined,
            AppColors.error,
          ),
          _section(
            'Câu hỏi chưa trả lời',
            summary.questions,
            Icons.help_outline,
            AppColors.warning,
          ),
          _section(
            'Phàn nàn / rủi ro',
            summary.risks,
            Icons.report_problem_outlined,
            AppColors.error,
          ),
          _section(
            'Chủ đề nổi bật',
            summary.keyTopics,
            Icons.tag,
            AppColors.primary,
          ),
          _section(
            'Quyết định',
            summary.decisions,
            Icons.check_circle_outline,
            AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    List<String> items,
    IconData icon,
    Color color,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(title, style: AppTextStyles.bodyMedium),
            ],
          ),
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

class _InsightsList extends StatelessWidget {
  final List<GroupInsight> insights;

  const _InsightsList({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Điểm cần chú ý', style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.s),
        if (insights.isEmpty)
          Text(
            'Chưa có điểm nào cần xử lý.',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          )
        else
          ...insights.take(5).map((insight) {
            return ListTile(
              dense: true,
              leading: const Icon(
                Icons.lightbulb_outline,
                color: AppColors.warning,
              ),
              title: Text(insight.title.isEmpty ? insight.type : insight.title),
              subtitle: Text(insight.description),
              trailing: Text(insight.priority.toString()),
            );
          }),
      ],
    );
  }
}
