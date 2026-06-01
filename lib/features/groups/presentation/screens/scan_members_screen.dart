import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../providers/scan_members_provider.dart';

class ScanMembersScreen extends ConsumerStatefulWidget {
  const ScanMembersScreen({super.key});

  @override
  ConsumerState<ScanMembersScreen> createState() => _ScanMembersScreenState();
}

class _ScanMembersScreenState extends ConsumerState<ScanMembersScreen> {
  final _linkController = TextEditingController();

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanMembersProvider);
    final notifier = ref.read(scanMembersProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            if (state.complianceError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppAlert(
                title: 'Hành động bị chặn',
                message: state.complianceError!,
                variant: AppAlertVariant.error,
              ),
            ],
            const SizedBox(height: AppSpacing.m),
            _ScanFormCard(
              linkController: _linkController,
              state: state,
              notifier: notifier,
              onScan: () => notifier.scanGroupLink(_linkController.text),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Expanded(
              child: state.members.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'Quét thành viên nhóm Zalo',
                      description:
                          'Dán link nhóm Zalo phía trên rồi nhấn "Quét thành viên" để lấy danh sách.\nDùng để tìm khách hàng tiềm năng từ các nhóm chung.',
                      height: 360,
                    )
                  : _MemberTable(state: state),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

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
              Text('CRM Khách Hàng', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Hệ thống quản trị và chăm sóc khách hàng Zalo chuyên nghiệp',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanFormCard extends StatelessWidget {
  final TextEditingController linkController;
  final ScanMembersState state;
  final ScanMembersNotifier notifier;
  final VoidCallback onScan;

  const _ScanFormCard({
    required this.linkController,
    required this.state,
    required this.notifier,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_none_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                'Quét thành viên nhóm Zalo',
                style: AppTextStyles.sectionTitle,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            'Dán link nhóm Zalo vào đây để quét danh sách thành viên. Hỗ trợ link dạng: https://zalo.me/g/...',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.m),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 720;
              final input = TextField(
                controller: linkController,
                style: AppTextStyles.body,
                decoration: const InputDecoration(
                  hintText:
                      'Dán link nhóm Zalo vào đây... VD: https://zalo.me/g/abc123',
                ),
              );
              final button = AppButton(
                text: 'Quét thành viên',
                icon: Icons.search,
                isLoading: state.isScanning,
                onPressed: onScan,
              );

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    input,
                    const SizedBox(height: AppSpacing.s),
                    button,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: input),
                  const SizedBox(width: AppSpacing.s),
                  button,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.m),
          const Divider(color: AppColors.borderSoft),
          const SizedBox(height: AppSpacing.s),
          if (state.savedGroups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              child: Text(
                'Chưa có nhóm nào được quét hoặc lưu.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else ...[
            Row(
              children: [
                const Icon(Icons.history, size: 16, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Nhóm đã quét gần đây (${state.savedGroups.length}):',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              height: 105,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: state.savedGroups.length,
                itemBuilder: (context, index) {
                  final group = state.savedGroups[index];
                  final isSelected = state.selectedGroupId == group.id;

                  return Container(
                    width: 220,
                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Stack(
                      children: [
                        Material(
                          color: isSelected
                              ? AppColors.primarySoft
                              : AppColors.surface,
                          borderRadius: AppSpacing.borderRadiusM,
                          child: InkWell(
                            onTap: () {
                              if (isSelected) {
                                notifier.selectSavedGroup(null);
                                linkController.clear();
                              } else {
                                notifier.selectSavedGroup(group.id);
                                linkController.text =
                                    'https://zalo.me/g/${group.id}';
                              }
                            },
                            borderRadius: AppSpacing.borderRadiusM,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: AppSpacing.borderRadiusM,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.borderSoft,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.surfaceMuted,
                                    backgroundImage: group.avatarUrl.isNotEmpty
                                        ? NetworkImage(group.avatarUrl)
                                        : null,
                                    child: group.avatarUrl.isEmpty
                                        ? Text(
                                            group.name.isNotEmpty
                                                ? group.name
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                                : 'G',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textSecondary,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: AppSpacing.s),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          group.name,
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${group.memberCount} thành viên',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () {
                              notifier.removeSavedGroup(group.id);
                              if (state.selectedGroupId == group.id) {
                                linkController.clear();
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: AppColors.borderSoft),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberTable extends StatelessWidget {
  final ScanMembersState state;

  const _MemberTable({required this.state});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  state.scannedGroupName != null
                      ? 'Thành viên nhóm: ${state.scannedGroupName}'
                      : 'Kết quả quét thành viên',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppSpacing.borderRadiusS,
                ),
                child: Text(
                  '${state.members.length} / ${state.scannedTotalMember ?? state.members.length} thành viên',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: state.members.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = state.members[index];
                final isOwner = member.role == 'Trưởng nhóm';
                final isAdmin = member.role == 'Phó nhóm';
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.surfaceMuted,
                        backgroundImage: member.avatarUrl.isNotEmpty ? NetworkImage(member.avatarUrl) : null,
                        child: member.avatarUrl.isNotEmpty
                            ? null
                            : Text(
                                member.name.isNotEmpty
                                    ? member.name.substring(0, 1).toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              member.id,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textMuted,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner || isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isOwner
                                ? AppColors.warningSoft
                                : AppColors.primarySoft,
                            borderRadius: AppSpacing.borderRadiusS,
                            border: Border.all(
                              color: isOwner
                                  ? AppColors.warning
                                  : AppColors.primary,
                            ),
                          ),
                          child: Text(
                            member.role,
                            style: AppTextStyles.caption.copyWith(
                              color: isOwner
                                  ? AppColors.warning
                                  : AppColors.primary,
                              fontSize: 10,
                            ),
                          ),
                        )
                      else
                        Text(
                          member.role,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
