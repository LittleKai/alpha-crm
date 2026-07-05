import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../providers/workflow_automation_provider.dart';

class TiktokSettingsScreen extends ConsumerStatefulWidget {
  const TiktokSettingsScreen({super.key});

  @override
  ConsumerState<TiktokSettingsScreen> createState() =>
      _TiktokSettingsScreenState();
}

class _TiktokSettingsScreenState extends ConsumerState<TiktokSettingsScreen> {
  static const _cloudWebhookUrl =
      'https://alpha-studio-backend.fly.dev/api/crm/tiktok/webhook';

  final _tiktokAccountNameController = TextEditingController();
  final _tiktokAccountIdController = TextEditingController();
  final _tiktokAppIdController = TextEditingController();
  final _tiktokVerifyTokenController = TextEditingController();
  final _tiktokAppSecretController = TextEditingController();
  final _tiktokAccessTokenController = TextEditingController();
  bool _tiktokEnabled = false;
  bool _tiktokEnforce24hWindow = true;
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
    _tiktokAccountNameController.dispose();
    _tiktokAccountIdController.dispose();
    _tiktokAppIdController.dispose();
    _tiktokVerifyTokenController.dispose();
    _tiktokAppSecretController.dispose();
    _tiktokAccessTokenController.dispose();
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
            const SizedBox(height: AppSpacing.m),

            // ── Verification-pending disclosure (always shown) ──
            const _StatusBanner(
              icon: Icons.info_outline,
              text:
                  'Tích hợp TikTok đang ở dạng khung sườn, mô phỏng cấu trúc Facebook Messenger. Phần gọi API thực tế (endpoint, chữ ký webhook, định dạng payload) cần được xác thực lại khi có tài liệu/credential chính thức từ TikTok Business Messaging API.',
              color: AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.m),

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

            // ── Connected accounts list ───────────────────────────────
            _buildAccountListCard(state.tiktokAccounts),
            const SizedBox(height: AppSpacing.l),

            // ── Add / edit form ───────────────────────────────────────
            if (_showForm)
              _buildTiktokSettingsCard(notifier)
            else
              OutlinedButton.icon(
                onPressed: _startAdd,
                icon: const Icon(Icons.add),
                label: const Text('Thêm tài khoản TikTok mới'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF010101),
                  side: const BorderSide(color: Color(0xFF010101)),
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
                    Icons.music_note_outlined,
                    color: Color(0xFF010101),
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Flexible(
                    child: Text(
                      'TikTok Messaging',
                      style: AppTextStyles.pageTitle.copyWith(
                        color: const Color(0xFF010101),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF25F4EE), Color(0xFFFE2C55)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'BUSINESS MESSAGING API',
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
          'Kết nối tài khoản TikTok để nhận và gửi tin nhắn qua CRM',
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
        title: 'API chính thức',
        subtitle: 'Chỉ dùng TikTok Business Messaging API',
      ),
      _InfoCard(
        icon: Icons.lock_outline,
        iconColor: Color(0xFF6366F1),
        title: 'Bảo mật cao',
        subtitle: 'Access token lưu local, App Secret gửi cloud để xác thực webhook',
      ),
      _InfoCard(
        icon: Icons.timer_outlined,
        iconColor: Color(0xFFF59E0B),
        title: 'Cửa sổ 24h',
        subtitle: 'Reply window policy (cần xác thực lại)',
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

  // ─── Connected accounts list ─────────────────────────────────────────

  Widget _buildAccountListCard(List<TiktokSettingsState> accounts) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tài khoản TikTok đã kết nối (${accounts.length})',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.m),
          if (accounts.isEmpty)
            Text(
              'Chưa có tài khoản TikTok nào được kết nối. Nhấn "Thêm tài khoản TikTok mới" bên dưới để bắt đầu.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            for (int i = 0; i < accounts.length; i++) ...[
              _buildAccountRow(accounts[i]),
              if (i < accounts.length - 1)
                const SizedBox(height: AppSpacing.s),
            ],
        ],
      ),
    );
  }

  Widget _buildAccountRow(TiktokSettingsState account) {
    final label = account.accountName.isNotEmpty
        ? account.accountName
        : account.accountId;
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
              color: const Color(0xFF010101).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.music_note_outlined,
              color: Color(0xFF010101),
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
                        color: account.enabled
                            ? AppColors.success
                            : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      account.enabled
                          ? 'Đang hoạt động (Account ID: ${account.accountId})'
                          : 'Đã tắt (Account ID: ${account.accountId})',
                      style: AppTextStyles.caption.copyWith(
                        color: account.enabled
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
            onPressed: () => _startEdit(account),
          ),
          IconButton(
            tooltip: 'Xoá',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
            onPressed: () => _confirmDeleteTiktokAccount(account),
          ),
        ],
      ),
    );
  }

  // ─── Main settings card ──────────────────────────────────────────────

  Widget _buildTiktokSettingsCard(WorkflowAutomationNotifier notifier) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.music_note_outlined,
                color: Color(0xFF010101),
                size: 24,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'TikTok Messaging',
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: const Color(0xFF010101),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Kết nối tài khoản TikTok với CRM qua TikTok Business Messaging API. Cho phép nhận và trả lời tin nhắn TikTok từ khách hàng trong Live Chat. Cấu trúc mô phỏng theo Facebook Messenger, cần xác thực lại khi có tài liệu TikTok thật.',
                      child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _tiktokEnabled,
                activeThumbColor: const Color(0xFF010101),
                onChanged: (value) =>
                    setState(() => _tiktokEnabled = value),
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
                ? 'Thêm tài khoản TikTok mới'
                : 'Đang chỉnh sửa tài khoản đã kết nối',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          LayoutBuilder(
            builder: (context, constraints) {
              final useColumns = constraints.maxWidth >= 820;
              final left = Column(
                children: [
                  _TextField(
                    controller: _tiktokAccountNameController,
                    label: 'Tên tài khoản',
                    hint: 'Alpha CRM',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _tiktokAccountIdController,
                    label: 'Account ID',
                    hint: '1234567890',
                    suffixTooltip: 'ID tài khoản Business được cấp khi đăng ký TikTok Business Messaging API (cần xác thực lại vị trí chính xác trong tài liệu TikTok thật).',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _tiktokAppIdController,
                    label: 'TikTok App ID',
                    hint: 'TikTok App ID',
                    suffixTooltip: 'Tạo ứng dụng tại TikTok for Business Developer Portal (cần xác thực lại URL/luồng chính thức khi có tài liệu thật).',
                  ),
                ],
              );
              final right = Column(
                children: [
                  _ReadOnlyCopyField(
                    label: 'Webhook callback URL (dán vào TikTok App)',
                    value: _cloudWebhookUrl,
                    tooltip: 'URL webhook cố định do cloud backend của Alpha CRM cung cấp. Dán URL này vào cấu hình webhook của TikTok App. Không cần ngrok hay tunnel local.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _tiktokVerifyTokenController,
                    label: 'Verify token',
                    hint: 'TikTok webhook verify token',
                    obscureText: true,
                    suffixTooltip: 'Chuỗi bảo mật tùy chọn do bạn tự đặt, dùng khi TikTok xác minh webhook. Phải khớp giữa CRM và cấu hình TikTok App. Token này được gửi lên cloud backend để xác thực webhook.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _tiktokAppSecretController,
                    label: 'App Secret',
                    hint: 'TikTok App Secret',
                    obscureText: true,
                    suffixTooltip: 'Lấy từ TikTok for Business Developer Portal. Được gửi lên cloud backend (mã hoá khi lưu) để xác thực chữ ký webhook — đây là ngoại lệ duy nhất, các thông tin khác vẫn lưu local.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _tiktokAccessTokenController,
                    label: 'Access token',
                    hint: 'act.xxxxx',
                    obscureText: true,
                    suffixTooltip: 'Access token cấp cho tài khoản Business. Token này chỉ lưu ở backend local, dùng để gửi tin nhắn trực tiếp tới TikTok API.',
                  ),
                ],
              );
              if (!useColumns) {
                return Column(
                  children: [
                    left,
                    const SizedBox(height: AppSpacing.s),
                    right,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(child: right),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.s),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _tiktokEnforce24hWindow,
            onChanged: (value) =>
                setState(() => _tiktokEnforce24hWindow = value != false),
            title: Row(
              children: [
                const Flexible(child: Text('Áp dụng cửa sổ phản hồi 24h (cần xác thực lại)')),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Mô phỏng theo chính sách cửa sổ phản hồi 24h của Messenger. Chưa xác thực đây có phải chính sách thật của TikTok Business Messaging API hay không.',
                  child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          const _CapabilityRow(
            icon: Icons.verified_user_outlined,
            label:
                'Chỉ dùng TikTok Business Messaging API chính thức, không dùng cookie cá nhân',
            iconColor: Color(0xFF10B981),
          ),
          const SizedBox(height: AppSpacing.s),
          const _CapabilityRow(
            icon: Icons.lock_outline,
            label:
                'Access token và verify token lưu ở backend local; App Secret được gửi lên cloud backend (mã hoá) để xác thực chữ ký webhook',
            iconColor: Color(0xFF6366F1),
          ),
          const SizedBox(height: AppSpacing.m),
          ElevatedButton.icon(
            onPressed: () => _saveTiktokAccount(notifier),
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _editingAccountId == null
                  ? 'Lưu tài khoản TikTok mới'
                  : 'Cập nhật tài khoản TikTok',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF010101),
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
      _tiktokEnabled = false;
      _tiktokEnforce24hWindow = true;
      _tiktokAccountNameController.clear();
      _tiktokAccountIdController.clear();
      _tiktokAppIdController.clear();
      _tiktokVerifyTokenController.clear();
      _tiktokAppSecretController.clear();
      _tiktokAccessTokenController.clear();
      _showForm = true;
    });
  }

  void _startEdit(TiktokSettingsState account) {
    setState(() {
      _editingAccountId = account.accountId;
      _editingCloudId = account.cloudId;
      _tiktokEnabled = account.enabled;
      _tiktokEnforce24hWindow = account.enforce24hWindow;
      _tiktokAccountNameController.text = account.accountName;
      _tiktokAccountIdController.text = account.accountId;
      _tiktokAppIdController.text = account.appId;
      _tiktokVerifyTokenController.text = account.verifyToken;
      _tiktokAppSecretController.text = account.appSecret;
      _tiktokAccessTokenController.text = account.accessToken;
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

  TiktokSettingsState _readTiktokSettings() {
    return TiktokSettingsState(
      enabled: _tiktokEnabled,
      accountName: _tiktokAccountNameController.text.trim(),
      accountId: _tiktokAccountIdController.text.trim(),
      appId: _tiktokAppIdController.text.trim(),
      webhookCallbackUrl: _cloudWebhookUrl,
      verifyToken: _tiktokVerifyTokenController.text.trim(),
      appSecret: _tiktokAppSecretController.text.trim(),
      accessToken: _tiktokAccessTokenController.text.trim(),
      enforce24hWindow: _tiktokEnforce24hWindow,
      cloudId: _editingCloudId,
    );
  }

  Future<void> _saveTiktokAccount(WorkflowAutomationNotifier notifier) async {
    await notifier.saveTiktokAccount(_readTiktokSettings());
    if (!mounted) return;
    if (ref.read(workflowAutomationProvider).errorText == null) {
      setState(() {
        _showForm = false;
        _editingAccountId = null;
        _editingCloudId = null;
      });
    }
  }

  Future<void> _confirmDeleteTiktokAccount(TiktokSettingsState account) async {
    final label = account.accountName.isNotEmpty
        ? account.accountName
        : account.accountId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Xoá tài khoản TikTok',
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
          'Bạn có chắc chắn muốn xoá tài khoản TikTok "$label" khỏi CRM không? CRM sẽ ngừng nhận và gửi tin nhắn cho tài khoản này.',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final accountId = account.accountId;
      await ref
          .read(workflowAutomationProvider.notifier)
          .deleteTiktokAccount(accountId);
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

class _ReadOnlyCopyField extends StatelessWidget {
  final String label;
  final String value;
  final String tooltip;

  const _ReadOnlyCopyField({
    required this.label,
    required this.value,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value),
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: tooltip,
              child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 18),
              tooltip: 'Sao chép',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép webhook URL.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? suffixTooltip;

  const _TextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffixTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
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
