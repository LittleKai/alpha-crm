import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/compliance_warnings_popup.dart';
import '../../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../../../friends/history/providers/friend_history_provider.dart';
import '../../providers/auto_approve_provider.dart';

class AutoApproveScreen extends ConsumerStatefulWidget {
  const AutoApproveScreen({super.key});

  @override
  ConsumerState<AutoApproveScreen> createState() => _AutoApproveScreenState();
}

class _AutoApproveScreenState extends ConsumerState<AutoApproveScreen> with SingleTickerProviderStateMixin {
  final _welcomeController = TextEditingController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(zaloIntegrationProvider.notifier).checkConnection();
      _welcomeController.text = ref.read(autoApproveProvider).welcomeMessage;
    });
  }

  @override
  void dispose() {
    _welcomeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(autoApproveProvider);
    final notifier = ref.read(autoApproveProvider.notifier);
    final zaloState = ref.watch(zaloIntegrationProvider);
    final activeAccounts = zaloState.accounts;
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useColumns = constraints.maxWidth >= 1100;
                  final leftCard = _buildSettingsCard(state, notifier);
                  final rightCard = _buildRightPanel(state, activeAccounts);

                  if (!useColumns) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          leftCard,
                          const SizedBox(height: AppSpacing.l),
                          rightCard,
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 11, child: leftCard),
                      const SizedBox(width: AppSpacing.l),
                      Expanded(flex: 9, child: rightCard),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: AppSpacing.borderRadiusS,
          ),
          child: Icon(Icons.check_rounded, color: AppColors.primary, size: 28),
        ),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tự động Duyệt kết bạn', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tự động đồng ý lời mời kết bạn Zalo gửi đến và gửi tin nhắn chào mừng theo cấu hình.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        const WarningIconButton(actionType: ZaloActionType.friendByPhone),
      ],
    );
  }

  Widget _buildSettingsCard(
    AutoApproveState state,
    AutoApproveNotifier notifier,
  ) {
    return AppCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s),
                Text(
                  'Cấu hình duyệt tự động',
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              'Tiến trình chạy ngầm sẽ giám sát và tự động đồng ý kết bạn gửi tới Zalo cá nhân của bạn, giúp tiết kiệm thời gian vận hành.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            _buildSwitchRow(
              title: 'Chế độ Tự động duyệt kết bạn',
              subtitle: 'Chấp nhận mọi lời mời kết bạn gửi đến theo thời gian thực.',
              value: state.autoApprove,
              onChanged: notifier.toggleAutoApprove,
              icon: Icons.person_add_alt_1_rounded,
              activeColor: const Color(0xFF10B981),
            ),
            const SizedBox(height: AppSpacing.m),

            // Sub-options depending on state.autoApprove
            AnimatedOpacity(
              opacity: state.autoApprove ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !state.autoApprove,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSwitchRow(
                      title: 'Gửi tin nhắn chào mừng',
                      subtitle: 'Tự động gửi tin nhắn chào mừng ngay sau khi duyệt kết bạn.',
                      value: state.sendWelcome,
                      onChanged: notifier.toggleSendWelcome,
                      icon: Icons.chat_bubble_outline_rounded,
                      activeColor: const Color(0xFF3B82F6),
                    ),
                    if (state.sendWelcome && state.autoApprove) ...[
                      const SizedBox(height: AppSpacing.m),
                      // AI settings & welcome message field as children of "Send Welcome" (indented)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.l),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSwitchRow(
                              title: 'AI tự động phản hồi bạn mới',
                              subtitle: 'Cho phép Chatbot AI tự trả lời tin nhắn đầu tiên từ bạn mới.',
                              value: state.autoReplyNewFriend,
                              onChanged: notifier.toggleAutoReplyNewFriend,
                              icon: Icons.smart_toy_outlined,
                              activeColor: const Color(0xFF8B5CF6),
                            ),
                            // Only show text field if AI auto reply is DISABLED
                            if (!state.autoReplyNewFriend) ...[
                              const SizedBox(height: AppSpacing.m),
                              Padding(
                                padding: const EdgeInsets.only(left: AppSpacing.s),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Nội dung tin nhắn chào mừng *',
                                      style: AppTextStyles.label.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    TextField(
                                      controller: _welcomeController,
                                      maxLines: 3,
                                      style: AppTextStyles.body,
                                      onChanged: notifier.updateWelcomeMessage,
                                      decoration: InputDecoration(
                                        hintText: 'Chào bạn! Rất vui được kết nối trên Zalo.',
                                        hintStyle: AppTextStyles.body.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                        contentPadding: const EdgeInsets.all(AppSpacing.m),
                                        border: OutlineInputBorder(
                                          borderRadius: AppSpacing.borderRadiusM,
                                          borderSide: BorderSide(color: AppColors.border),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: AppSpacing.borderRadiusM,
                                          borderSide: BorderSide(color: AppColors.borderSoft),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: AppSpacing.borderRadiusM,
                                          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.m),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.04),
                borderRadius: AppSpacing.borderRadiusM,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Text(
                      'Hệ thống lắng nghe các sự kiện kết bạn trực tiếp từ Zalo. Vui lòng giữ ứng dụng và tài khoản Zalo hoạt động trực tuyến để tiến trình tự động duyệt hoạt động ổn định.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
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

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    Color? activeColor,
  }) {
    final effectiveColor = activeColor ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface,
        borderRadius: AppSpacing.borderRadiusM,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s),
            decoration: BoxDecoration(
              color: (value ? effectiveColor : AppColors.textMuted).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: value ? effectiveColor : AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: effectiveColor.withValues(alpha: 0.2),
            activeColor: effectiveColor,
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel(
    AutoApproveState state,
    List<ZaloConnectedAccount> accounts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: _buildRunningAccountsCard(state, accounts),
        ),
        const SizedBox(height: AppSpacing.l),
        Expanded(
          flex: 5,
          child: _buildRecentApprovalsCard(ref),
        ),
      ],
    );
  }

  Widget _buildRunningAccountsCard(
    AutoApproveState state,
    List<ZaloConnectedAccount> accounts,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tài khoản đang chạy duyệt',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 15),
              ),
              if (accounts.isNotEmpty && state.autoApprove)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.5),
                            blurRadius: 4 + _pulseController.value * 6,
                            spreadRadius: _pulseController.value * 3,
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Icon(Icons.people_outline, color: AppColors.textSecondary, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Tổng số tài khoản kết nối: ',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                '${accounts.length}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Expanded(
            child: accounts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.link_off_rounded,
                          color: AppColors.textMuted,
                          size: 32,
                        ),
                        const SizedBox(height: AppSpacing.s),
                        Text(
                          'Chưa có tài khoản nào kết nối.',
                          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: accounts.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: AppColors.borderSoft, height: 1),
                    itemBuilder: (context, index) {
                      final acc = accounts[index];
                      final cleanLabel = acc.label.replaceAll(
                        RegExp(r'\s*\([^)]*\)$'),
                        '',
                      );
                      final isRunning = state.autoApprove;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.surfaceMuted,
                              backgroundImage: acc.avatarUrl.isNotEmpty
                                  ? NetworkImage(acc.avatarUrl)
                                  : null,
                              child: acc.avatarUrl.isEmpty
                                  ? Text(
                                      cleanLabel.isNotEmpty
                                          ? cleanLabel[0].toUpperCase()
                                          : 'A',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cleanLabel,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isRunning
                                        ? 'Đang lắng nghe sự kiện kết bạn...'
                                        : 'Tạm dừng tự động duyệt',
                                    style: AppTextStyles.caption.copyWith(
                                      color: isRunning ? AppColors.success : AppColors.textSecondary,
                                      fontWeight: isRunning ? FontWeight.w500 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s),
                            if (isRunning)
                              const Icon(
                                Icons.sync,
                                color: AppColors.success,
                                size: 16,
                              )
                            else
                              Icon(
                                Icons.pause_circle_filled_rounded,
                                color: AppColors.textSecondary,
                                size: 16,
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

  Widget _buildRecentApprovalsCard(WidgetRef ref) {
    final historyState = ref.watch(friendHistoryProvider);
    final records = historyState.records;
    final displayRecords = records.take(10).toList();

    final zaloState = ref.watch(zaloIntegrationProvider);
    final accounts = zaloState.accounts;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: Colors.indigoAccent, size: 20),
              const SizedBox(width: AppSpacing.s),
              Text(
                'Nhật ký duyệt gần đây',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Expanded(
            child: displayRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.playlist_remove_rounded,
                          color: AppColors.textMuted,
                          size: 32,
                        ),
                        const SizedBox(height: AppSpacing.s),
                        Text(
                          'Chưa có hoạt động duyệt kết bạn nào.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: displayRecords.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: AppColors.borderSoft, height: 1),
                    itemBuilder: (context, index) {
                      final item = displayRecords[index];
                      
                      final cleanAccountLabel = item.accountLabel.replaceAll(RegExp(r'\s*\([^)]*\)$'), '').trim().toLowerCase();
                      final matchingAccount = accounts.firstWhere(
                        (acc) {
                          final cleanAccLabel = acc.label.replaceAll(RegExp(r'\s*\([^)]*\)$'), '').trim().toLowerCase();
                          return cleanAccLabel == cleanAccountLabel;
                        },
                        orElse: () => const ZaloConnectedAccount(
                          id: '', 
                          label: '', 
                          avatarUrl: '',
                          connected: false,
                          listenerRunning: false,
                        ),
                      );

                      final hasZaloAvatar = matchingAccount.avatarUrl.isNotEmpty;
                      final int colorIndex = item.targetName.hashCode % 5;
                      final List<Color> avatarColors = [
                        Colors.blue,
                        Colors.teal,
                        Colors.orange,
                        Colors.purple,
                        Colors.red,
                      ];
                      final Color textAvatarColor = avatarColors[colorIndex];
                      final Color bgAvatarColor = textAvatarColor.withValues(alpha: 0.1);

                      final hasWelcomeMsg = item.message.isNotEmpty;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: hasZaloAvatar ? AppColors.surfaceMuted : bgAvatarColor,
                              backgroundImage: hasZaloAvatar
                                  ? NetworkImage(matchingAccount.avatarUrl)
                                  : null,
                              child: !hasZaloAvatar
                                  ? Text(
                                      item.targetName.isNotEmpty
                                          ? item.targetName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: textAvatarColor,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item.targetName.isNotEmpty ? item.targetName : 'Người dùng Zalo',
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        item.timestamp,
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        item.targetPhone.isNotEmpty ? item.targetPhone : 'Ẩn số',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.s),
                                      Container(
                                        width: 3,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: AppColors.textSecondary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.s),
                                      Expanded(
                                        child: Text(
                                          hasWelcomeMsg
                                              ? 'Đã duyệt & Gửi tin chào mừng'
                                              : 'Đã duyệt kết bạn',
                                          style: AppTextStyles.caption.copyWith(
                                            color: hasWelcomeMsg
                                                ? Colors.orangeAccent
                                                : Colors.teal,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
