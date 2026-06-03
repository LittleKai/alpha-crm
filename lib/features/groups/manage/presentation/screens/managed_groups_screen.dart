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
import '../../../../zalo_integration/providers/zalo_integration_provider.dart';
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
                'Bật quản lý nhóm, tạo tóm tắt AI và theo dõi insight vận hành.',
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
                                style: const TextStyle(
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
              title: 'Chưa có nhóm',
              description:
                  state.errorMessage ??
                  'Bấm Đồng bộ để hệ thống tải danh sách nhóm Zalo.',
              height: 360,
            )
          : ListView.separated(
              itemCount: state.groups.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final group = state.groups[index];
                final selected = group.id == state.selectedGroup?.id;
                final hasAvatar =
                    group.avatarUrl.isNotEmpty &&
                    group.avatarUrl.startsWith('http');
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
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${group.memberCount} thành viên - ${group.accountId}',
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
              title: 'Chọn nhóm để quản lý',
              description: 'Tóm tắt, insight và xuất file sẽ hiển thị tại đây.',
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
                                    : (group.summaryCadence == 'monthly'
                                          ? 'Hàng tháng'
                                          : group.summaryCadence)),
                          variant: AppBadgeVariant.info,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AppButton(
                text: 'Tóm tắt AI',
                icon: Icons.summarize_outlined,
                isLoading: state.isWorking,
                onPressed: group.isManaged && !state.isWorking
                    ? notifier.summarizeSelected
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
                Text('Tóm tắt gần đây', style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.s),
                if (state.selectedSummaries.isEmpty)
                  Text(
                    'Chưa có tóm tắt cho nhóm này.',
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

class _InsightsList extends StatelessWidget {
  final List<GroupInsight> insights;

  const _InsightsList({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Insight mở', style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.s),
        if (insights.isEmpty)
          Text(
            'Chưa có insight cần xử lý.',
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
