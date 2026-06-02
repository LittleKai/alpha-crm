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
import '../../providers/managed_groups_provider.dart';

class ManagedGroupsScreen extends ConsumerWidget {
  const ManagedGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(managedGroupsProvider);
    final notifier = ref.read(managedGroupsProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
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

class _Header extends StatelessWidget {
  final ManagedGroupsState state;
  final ManagedGroupsNotifier notifier;

  const _Header({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.groups_2_outlined, color: AppColors.primary, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quan ly nhom Zalo', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Bat quan ly nhom, tao tom tat AI va theo doi insight van hanh.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Text('Chi managed', style: AppTextStyles.caption),
            Switch(
              value: state.showManagedOnly,
              onChanged: notifier.toggleManagedOnly,
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.s),
        AppButton(
          text: 'Dong bo',
          icon: Icons.sync,
          isLoading: state.isWorking,
          onPressed: state.isWorking ? null : notifier.syncGroups,
        ),
      ],
    );
  }
}

class _GroupsList extends StatelessWidget {
  final ManagedGroupsState state;
  final ManagedGroupsNotifier notifier;

  const _GroupsList({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s),
      child: state.groups.isEmpty
          ? AppEmptyState(
              icon: Icons.groups_outlined,
              title: 'Chua co nhom',
              description:
                  state.errorMessage ??
                  'Bam Dong bo de agent lay danh sach nhom Zalo.',
              height: 360,
            )
          : ListView.separated(
              itemCount: state.groups.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final group = state.groups[index];
                final selected = group.id == state.selectedGroup?.id;
                return ListTile(
                  selected: selected,
                  selectedTileColor: AppColors.primarySoft,
                  leading: const CircleAvatar(
                    child: Icon(Icons.groups_outlined),
                  ),
                  title: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${group.memberCount} thanh vien - ${group.accountId}',
                  ),
                  trailing: Switch(
                    value: group.isManaged,
                    onChanged: (value) => notifier.setManaged(group, value),
                  ),
                  onTap: () => notifier.selectGroup(group),
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

  @override
  Widget build(BuildContext context) {
    final group = state.selectedGroup;
    if (group == null) {
      return AppCard(
        child: Column(
          children: [
            const AppEmptyState(
              icon: Icons.manage_search_outlined,
              title: 'Chon nhom de quan ly',
              description: 'Tom tat, insight va export se hien thi tai day.',
              height: 260,
            ),
            _InsightsList(insights: state.insights),
          ],
        ),
      );
    }

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
                          label: group.isManaged ? 'Managed' : 'Unmanaged',
                          variant: group.isManaged
                              ? AppBadgeVariant.success
                              : AppBadgeVariant.neutral,
                        ),
                        AppBadge(
                          label: group.summaryCadence,
                          variant: AppBadgeVariant.info,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AppButton(
                text: 'Tom tat AI',
                icon: Icons.summarize_outlined,
                isLoading: state.isWorking,
                onPressed: group.isManaged && !state.isWorking
                    ? notifier.summarizeSelected
                    : null,
              ),
              const SizedBox(width: AppSpacing.s),
              AppButton(
                text: 'Export',
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
                Text('Tom tat gan day', style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.s),
                if (state.selectedSummaries.isEmpty)
                  Text(
                    'Chua co tom tat cho nhom nay.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                  )
                else
                  ...state.selectedSummaries.map((summary) {
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
                    );
                  }),
                const SizedBox(height: AppSpacing.m),
                _InsightsList(insights: state.insights),
                if (state.exportCsv != null && state.exportCsv!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.m),
                  Text('CSV export preview', style: AppTextStyles.bodyMedium),
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

class _InsightsList extends StatelessWidget {
  final List<GroupInsight> insights;

  const _InsightsList({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Insight mo', style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.s),
        if (insights.isEmpty)
          Text(
            'Chua co insight can xu ly.',
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
