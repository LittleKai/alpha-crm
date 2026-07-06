import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../providers/workflow_automation_provider.dart';

class TelegramSettingsScreen extends ConsumerStatefulWidget {
  const TelegramSettingsScreen({super.key});

  @override
  ConsumerState<TelegramSettingsScreen> createState() =>
      _TelegramSettingsScreenState();
}

class _TelegramSettingsScreenState
    extends ConsumerState<TelegramSettingsScreen> {
  final _telegramAccountNameController = TextEditingController();
  final _telegramBotTokenController = TextEditingController();
  bool _telegramEnabled = false;
  bool _showForm = false;
  String? _editingAccountId;
  String? _editingCloudId;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(workflowAutomationProvider.notifier).loadN8nSettings(),
    );
  }

  @override
  void dispose() {
    _telegramAccountNameController.dispose();
    _telegramBotTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowAutomationProvider);
    final notifier = ref.read(workflowAutomationProvider.notifier);

    final isMobile = ResponsiveBreakpoints.isMobile(context);

    ref.listen(workflowAutomationProvider, (previous, next) {
      if (next.statusText != null &&
          next.statusText != previous?.statusText &&
          mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.statusText!)));
      }
    });

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            _buildHeader(state.isLoading),
            const SizedBox(height: AppSpacing.l),

            // ── Error banner ──────────────────────────────────────────
            if (state.errorText != null) ...[
              _StatusBanner(
                icon: Icons.warning_amber_rounded,
                text: state.errorText!,
                color: AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.m),
            ],

            // ── Overview info cards ───────────────────────────────────
            _buildOverviewSection(isMobile),
            const SizedBox(height: AppSpacing.l),

            // ── Connected bots list ────────────────────────────────────
            _buildBotListCard(state.telegramBots),
            const SizedBox(height: AppSpacing.l),

            // ── Add / edit form ───────────────────────────────────────
            if (_showForm)
              _buildTelegramSettingsCard(notifier)
            else
              OutlinedButton.icon(
                onPressed: _startAdd,
                icon: const Icon(Icons.add),
                label: const Text('Thêm bot Telegram mới'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF26A5E4),
                  side: const BorderSide(color: Color(0xFF26A5E4)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────

  Widget _buildHeader(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.send_outlined,
                    color: Color(0xFF26A5E4),
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Flexible(
                    child: Text(
                      'Telegram Bot',
                      style: AppTextStyles.pageTitle.copyWith(
                        color: const Color(0xFF26A5E4),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26A5E4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'TELEGRAM BOT API',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Kết nối bot Telegram để nhận và gửi tin nhắn qua CRM',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // ─── Overview section ────────────────────────────────────────────────

  Widget _buildOverviewSection(bool isMobile) {
    const cards = [
      _InfoCard(
        icon: Icons.verified_user_outlined,
        iconColor: Color(0xFF10B981),
        title: 'Telegram Bot API',
        subtitle: 'Dùng Bot API chính thức của Telegram, không cần app review',
      ),
      _InfoCard(
        icon: Icons.lock_outline,
        iconColor: Color(0xFF6366F1),
        title: 'Bot token bảo mật',
        subtitle: 'Token lưu local; cloud chỉ giữ bản sao để định danh webhook',
      ),
      _InfoCard(
        icon: Icons.webhook_outlined,
        iconColor: Color(0xFFF59E0B),
        title: 'Tự động đăng ký webhook',
        subtitle: 'CRM tự gọi setWebhook khi lưu bot, không cần thao tác thủ công',
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: AppSpacing.s),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) const SizedBox(width: AppSpacing.m),
        ],
      ],
    );
  }

  // ─── Connected bots list ──────────────────────────────────────────────

  Widget _buildBotListCard(List<TelegramSettingsState> bots) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bot Telegram đã kết nối (${bots.length})',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.m),
          if (bots.isEmpty)
            Text(
              'Chưa có bot Telegram nào được kết nối. Nhấn "Thêm bot Telegram mới" bên dưới để bắt đầu.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            for (int i = 0; i < bots.length; i++) ...[
              _buildBotRow(bots[i]),
              if (i < bots.length - 1) const SizedBox(height: AppSpacing.s),
            ],
        ],
      ),
    );
  }

  Widget _buildBotRow(TelegramSettingsState bot) {
    final label = bot.accountName.isNotEmpty ? bot.accountName : bot.accountId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF26A5E4).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.send_outlined,
              color: Color(0xFF26A5E4),
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: bot.enabled
                            ? AppColors.success
                            : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      bot.enabled
                          ? 'Đang hoạt động (Bot ID: ${bot.accountId})'
                          : 'Đã tắt (Bot ID: ${bot.accountId})',
                      style: AppTextStyles.caption.copyWith(
                        color: bot.enabled
                            ? AppColors.successText
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Chỉnh sửa',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _startEdit(bot),
          ),
          IconButton(
            tooltip: 'Xoá',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
            onPressed: () => _confirmDeleteTelegramBot(bot),
          ),
        ],
      ),
    );
  }

  // ─── Main settings card ──────────────────────────────────────────────

  Widget _buildTelegramSettingsCard(WorkflowAutomationNotifier notifier) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.send_outlined,
                color: Color(0xFF26A5E4),
                size: 24,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Telegram Bot',
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: const Color(0xFF26A5E4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Kết nối một Telegram Bot với CRM. Khi lưu, CRM sẽ tự động gọi getMe để xác định bot và setWebhook để đăng ký nhận tin nhắn — không cần cấu hình thủ công.',
                      child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _telegramEnabled,
                activeThumbColor: const Color(0xFF26A5E4),
                onChanged: (value) =>
                    setState(() => _telegramEnabled = value),
              ),
              IconButton(
                tooltip: 'Đóng',
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: _cancelForm,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _editingAccountId == null
                ? 'Thêm bot Telegram mới'
                : 'Đang chỉnh sửa bot đã kết nối',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          _TextField(
            controller: _telegramAccountNameController,
            label: 'Tên hiển thị (tuỳ chọn)',
            hint: 'Alpha CRM Bot',
          ),
          const SizedBox(height: AppSpacing.s),
          _TextField(
            controller: _telegramBotTokenController,
            label: 'Bot token',
            hint: '123456789:ABC-DEF...',
            obscureText: true,
            suffixTooltip: 'Token cấp bởi @BotFather trên Telegram khi tạo bot. CRM dùng token này để gọi getMe (xác định bot) và setWebhook (đăng ký nhận tin nhắn) khi bạn lưu cấu hình.',
          ),
          const SizedBox(height: AppSpacing.s),
          const _CapabilityRow(
            icon: Icons.verified_user_outlined,
            label:
                'Chỉ dùng Telegram Bot API chính thức, không dùng tài khoản cá nhân',
            iconColor: Color(0xFF10B981),
          ),
          const SizedBox(height: AppSpacing.s),
          const _CapabilityRow(
            icon: Icons.lock_outline,
            label:
                'Bot token lưu ở backend local, dùng để gửi tin nhắn trực tiếp qua Telegram Bot API',
            iconColor: Color(0xFF6366F1),
          ),
          const SizedBox(height: AppSpacing.m),
          ElevatedButton.icon(
            onPressed: () => _saveTelegramBot(notifier),
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _editingAccountId == null
                  ? 'Lưu bot Telegram mới'
                  : 'Cập nhật bot Telegram',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF26A5E4),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ─── State helpers ───────────────────────────────────────────────────

  void _startAdd() {
    setState(() {
      _editingAccountId = null;
      _editingCloudId = null;
      _telegramEnabled = false;
      _telegramAccountNameController.clear();
      _telegramBotTokenController.clear();
      _showForm = true;
    });
  }

  void _startEdit(TelegramSettingsState bot) {
    setState(() {
      _editingAccountId = bot.accountId;
      _editingCloudId = bot.cloudId;
      _telegramEnabled = bot.enabled;
      _telegramAccountNameController.text = bot.accountName;
      _telegramBotTokenController.text = bot.botToken;
      _showForm = true;
    });
  }

  void _cancelForm() {
    setState(() {
      _showForm = false;
      _editingAccountId = null;
      _editingCloudId = null;
    });
  }

  TelegramSettingsState _readTelegramSettings() {
    return TelegramSettingsState(
      enabled: _telegramEnabled,
      accountName: _telegramAccountNameController.text.trim(),
      accountId: _editingAccountId ?? '',
      botToken: _telegramBotTokenController.text.trim(),
      cloudId: _editingCloudId,
    );
  }

  Future<void> _saveTelegramBot(WorkflowAutomationNotifier notifier) async {
    await notifier.saveTelegramBot(_readTelegramSettings());
    if (!mounted) return;
    if (ref.read(workflowAutomationProvider).errorText == null) {
      setState(() {
        _showForm = false;
        _editingAccountId = null;
        _editingCloudId = null;
      });
    }
  }

  Future<void> _confirmDeleteTelegramBot(TelegramSettingsState bot) async {
    final label = bot.accountName.isNotEmpty ? bot.accountName : bot.accountId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Xoá bot Telegram',
        icon: Icons.delete_outline_rounded,
        actions: [
          AppDialogAction(
            text: 'Huỷ',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppDialogAction(
            text: 'Xác Nhận Xoá',
            variant: AppButtonVariant.destructive,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
        child: Text(
          'Bạn có chắc chắn muốn xoá bot Telegram "$label" khỏi CRM không? CRM sẽ ngừng nhận và gửi tin nhắn qua bot này.',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final accountId = bot.accountId;
      await ref
          .read(workflowAutomationProvider.notifier)
          .deleteTelegramBot(accountId);
      if (mounted && _editingAccountId == accountId) {
        setState(() {
          _showForm = false;
          _editingAccountId = null;
          _editingCloudId = null;
        });
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Private helper widgets
// ═══════════════════════════════════════════════════════════════════

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: AppSpacing.borderRadiusM,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _CapabilityRow({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: AppSpacing.s),
        Expanded(child: Text(label, style: AppTextStyles.body)),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusBanner({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.s),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final String? suffixTooltip;

  const _TextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.suffixTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: suffixTooltip != null
            ? Tooltip(
                message: suffixTooltip!,
                child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
              )
            : null,
      ),
    );
  }
}
