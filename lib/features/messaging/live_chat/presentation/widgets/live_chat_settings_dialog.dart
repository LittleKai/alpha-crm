import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../settings/providers/settings_provider.dart';
import '../../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../providers/live_chat_provider.dart';

Future<void> showLiveChatSettingsDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const LiveChatSettingsDialog(),
  );
}

class LiveChatSettingsDialog extends ConsumerStatefulWidget {
  const LiveChatSettingsDialog({super.key});

  @override
  ConsumerState<LiveChatSettingsDialog> createState() =>
      _LiveChatSettingsDialogState();
}

class _LiveChatSettingsDialogState
    extends ConsumerState<LiveChatSettingsDialog> {
  Map<String, bool> _aiAutoReply = const {};
  int _pauseCooldownMinutes = 10;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notifier = ref.read(liveChatProvider.notifier);
    final settings = await notifier.getAccountAiAutoReply();
    final cooldown = await notifier.getOperatorPauseCooldownMinutes();
    if (!mounted) return;
    setState(() {
      _aiAutoReply = settings;
      _pauseCooldownMinutes = cooldown;
      _loading = false;
    });
  }

  Future<void> _saveCooldown(int minutes) async {
    final saved = await ref
        .read(liveChatProvider.notifier)
        .setOperatorPauseCooldownMinutes(minutes);
    if (!mounted) return;
    setState(() => _pauseCooldownMinutes = saved);
  }

  // Accounts without an explicit setting default to ON.
  bool _isEnabled(String accountId) => _aiAutoReply[accountId] ?? true;

  Future<void> _toggle(String accountId, bool value) async {
    setState(() => _aiAutoReply = {..._aiAutoReply, accountId: value});
    final ok = await ref
        .read(liveChatProvider.notifier)
        .setAccountAiAutoReply(accountId, value);
    if (!mounted) return;
    if (!ok) {
      setState(() => _aiAutoReply = {..._aiAutoReply, accountId: !value});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu cài đặt. Kiểm tra kết nối bridge cục bộ.'),
        ),
      );
    }
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color backgroundColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusS),
          ),
          child: Icon(
            icon,
            size: 16,
            color: iconColor,
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(zaloIntegrationProvider).accounts;

    return AppDialog(
      title: 'Cài đặt Live Chat',
      subtitle: 'Tùy chỉnh tự động trả lời AI cho từng tài khoản Zalo.',
      icon: Icons.settings_outlined,
      width: 520,
      actions: [
        AppDialogAction(
          text: 'Đóng',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.notifications_none_outlined,
              title: 'Thông báo',
              iconColor: AppColors.infoText,
              backgroundColor: AppColors.infoSoft,
            ),
            const SizedBox(height: AppSpacing.s),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: ref.watch(
                settingsProvider.select(
                  (s) => s.settings.liveChatNotifications,
                ),
              ),
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .updateLiveChatNotifications(v),
              title: Text('Thông báo trên màn hình', style: AppTextStyles.body),
              subtitle: Text(
                'Hiện thông báo desktop khi có tin nhắn mới đến.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Divider(
              color: AppColors.borderSoft,
              thickness: 1,
              height: AppSpacing.xl,
            ),
            _buildSectionHeader(
              icon: Icons.smart_toy_outlined,
              title: 'Tự động trả lời bằng AI',
              iconColor: AppColors.isDarkMode
                  ? const Color(0xFFA78BFA)
                  : const Color(0xFF7C3AED),
              backgroundColor: AppColors.purpleSoft,
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Khi bật, chatbot AI sẽ tự động trả lời tin nhắn đến (kể cả tin '
              'đầu tiên của hội thoại mới) cho tài khoản đó. Khi tắt, bạn tự trả '
              'lời thủ công.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.m),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                child: Text(
                  'Chưa có tài khoản Zalo nào được kết nối.',
                  style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                ),
              )
            else
              ...accounts.map((account) {
                final cleanLabel = account.label.replaceAll(
                  RegExp(r'\s*\([^)]*\)$'),
                  '',
                );
                return _AccountAiRow(
                  label: cleanLabel.isNotEmpty ? cleanLabel : account.id,
                  avatarUrl: account.avatarUrl,
                  value: _isEnabled(account.id),
                  onChanged: (v) => _toggle(account.id, v),
                );
              }),
            Divider(
              color: AppColors.borderSoft,
              thickness: 1,
              height: AppSpacing.xl,
            ),
            _buildSectionHeader(
              icon: Icons.timer_outlined,
              title: 'Tạm nghỉ khi người trực trả lời',
              iconColor: AppColors.warningText,
              backgroundColor: AppColors.warningSoft,
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Khi bạn (hoặc bạn trả lời từ điện thoại) nhắn trong một hội thoại, '
              'AI tạm nghỉ ở hội thoại đó. Sau khoảng thời gian này mà không có '
              'tin tay nào nữa, AI tự bật lại.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s),
            if (!_loading)
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _pauseCooldownMinutes
                          .clamp(5, 120)
                          .toDouble(),
                      min: 5,
                      max: 120,
                      divisions: 23,
                      label: '$_pauseCooldownMinutes phút',
                      onChanged: (v) =>
                          setState(() => _pauseCooldownMinutes = v.round()),
                      onChangeEnd: (v) => _saveCooldown(v.round()),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '$_pauseCooldownMinutes phút',
                      textAlign: TextAlign.end,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountAiRow extends StatelessWidget {
  final String label;
  final String avatarUrl;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AccountAiRow({
    required this.label,
    required this.avatarUrl,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primarySoft,
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl.isEmpty
                ? Text(
                    label.isNotEmpty ? label[0].toUpperCase() : '?',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
