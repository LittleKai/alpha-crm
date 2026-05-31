import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../mock/mock_groups.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_select_field.dart';
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
              selectedGroupId: state.selectedGroupId,
              isScanning: state.isScanning,
              onScan: () => notifier.scanGroupLink(_linkController.text),
              onSavedGroupChanged: (value) {
                notifier.selectSavedGroup(value);
                if (value == null || value == 'none') {
                  _linkController.clear();
                  return;
                }
                _linkController.text = 'https://zalo.me/g/$value';
              },
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
                  : _ResultPlaceholder(count: state.members.length),
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
  final String? selectedGroupId;
  final bool isScanning;
  final VoidCallback onScan;
  final ValueChanged<String?> onSavedGroupChanged;

  const _ScanFormCard({
    required this.linkController,
    required this.selectedGroupId,
    required this.isScanning,
    required this.onScan,
    required this.onSavedGroupChanged,
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
                isLoading: isScanning,
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
          Row(
            children: [
              Text('Xem lại nhóm đã quét:', style: AppTextStyles.bodyMedium),
              const SizedBox(width: AppSpacing.m),
              SizedBox(
                width: 220,
                child: AppSelectField<String>(
                  value: selectedGroupId ?? 'none',
                  items: [
                    const DropdownMenuItem(
                      value: 'none',
                      child: Text('-- Chọn nhóm đã lưu --'),
                    ),
                    ...MockGroups.savedGroups.map(
                      (group) => DropdownMenuItem(
                        value: group.id,
                        child: Text(group.name),
                      ),
                    ),
                  ],
                  onChanged: onSavedGroupChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultPlaceholder extends StatelessWidget {
  final int count;

  const _ResultPlaceholder({required this.count});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Center(
        child: Text(
          'Đã quét được $count thành viên.',
          style: AppTextStyles.sectionTitle,
        ),
      ),
    );
  }
}
