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

class InstagramSettingsScreen extends ConsumerStatefulWidget {
  const InstagramSettingsScreen({super.key});

  @override
  ConsumerState<InstagramSettingsScreen> createState() =>
      _InstagramSettingsScreenState();
}

class _InstagramSettingsScreenState
    extends ConsumerState<InstagramSettingsScreen> {
  static const _cloudWebhookUrl =
      'https://alpha-studio-backend.fly.dev/api/crm/instagram/webhook';

  final _instagramAccountNameController = TextEditingController();
  final _instagramAccountIdController = TextEditingController();
  final _instagramAppIdController = TextEditingController();
  final _instagramVerifyTokenController = TextEditingController();
  final _instagramAppSecretController = TextEditingController();
  final _instagramAccessTokenController = TextEditingController();
  bool _instagramEnabled = false;
  bool _instagramEnforce24hWindow = true;
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
    _instagramAccountNameController.dispose();
    _instagramAccountIdController.dispose();
    _instagramAppIdController.dispose();
    _instagramVerifyTokenController.dispose();
    _instagramAppSecretController.dispose();
    _instagramAccessTokenController.dispose();
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

            // ── Connected accounts list ───────────────────────────────
            _buildAccountListCard(state.instagramAccounts),
            const SizedBox(height: AppSpacing.l),

            // ── Add / edit form ───────────────────────────────────────
            if (_showForm)
              _buildInstagramSettingsCard(notifier)
            else
              OutlinedButton.icon(
                onPressed: _startAdd,
                icon: const Icon(Icons.add),
                label: const Text('Thêm tài khoản Instagram mới'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE1306C),
                  side: const BorderSide(color: Color(0xFFE1306C)),
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
                    Icons.camera_alt_outlined,
                    color: Color(0xFFE1306C),
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Flexible(
                    child: Text(
                      'Instagram Messaging',
                      style: AppTextStyles.pageTitle.copyWith(
                        color: const Color(0xFFE1306C),
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
                        colors: [
                          Color(0xFF833AB4),
                          Color(0xFFFD1D1D),
                          Color(0xFFF77737),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'META MESSAGING API',
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
          'Kết nối tài khoản Instagram để nhận và gửi tin nhắn qua CRM',
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
        subtitle: 'Dùng Instagram Messaging API (Meta Graph API), chung hạ tầng với Facebook Messenger',
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
        subtitle: 'Chính sách phản hồi 24h theo Messenger Platform Policy',
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

  Widget _buildAccountListCard(List<InstagramSettingsState> accounts) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tài khoản Instagram đã kết nối (${accounts.length})',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.m),
          if (accounts.isEmpty)
            Text(
              'Chưa có tài khoản Instagram nào được kết nối. Nhấn "Thêm tài khoản Instagram mới" bên dưới để bắt đầu.',
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

  Widget _buildAccountRow(InstagramSettingsState account) {
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
              color: const Color(0xFFE1306C).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: Color(0xFFE1306C),
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
            onPressed: () => _confirmDeleteInstagramAccount(account),
          ),
        ],
      ),
    );
  }

  // ─── Main settings card ──────────────────────────────────────────────

  Widget _buildInstagramSettingsCard(WorkflowAutomationNotifier notifier) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFFE1306C),
                size: 24,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Instagram Messaging',
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: const Color(0xFFE1306C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Kết nối tài khoản Instagram (Professional/Business, liên kết với Facebook Page) với CRM qua Instagram Messaging API. Cho phép nhận và trả lời tin nhắn Instagram Direct từ khách hàng trong Live Chat.',
                      child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _instagramEnabled,
                activeThumbColor: const Color(0xFFE1306C),
                onChanged: (value) =>
                    setState(() => _instagramEnabled = value),
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
                ? 'Thêm tài khoản Instagram mới'
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
                    controller: _instagramAccountNameController,
                    label: 'Tên tài khoản',
                    hint: 'Alpha CRM',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _instagramAccountIdController,
                    label: 'Instagram Account ID',
                    hint: '1789...',
                    suffixTooltip: 'ID tài khoản Instagram chuyên nghiệp (Professional/Business) đã liên kết với Facebook Page, lấy từ Meta Business Suite hoặc Graph API Explorer.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _instagramAppIdController,
                    label: 'Meta App ID',
                    hint: 'Meta App ID',
                    suffixTooltip: 'Cùng Meta App dùng cho Facebook Messenger, tạo tại Meta for Developers.',
                  ),
                ],
              );
              final right = Column(
                children: [
                  _ReadOnlyCopyField(
                    label: 'Webhook callback URL (dán vào Meta App)',
                    value: _cloudWebhookUrl,
                    tooltip: 'URL webhook cố định do cloud backend của Alpha CRM cung cấp. Dán URL này vào cấu hình webhook Instagram của Meta App. Không cần ngrok hay tunnel local.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _instagramVerifyTokenController,
                    label: 'Verify token',
                    hint: 'Instagram webhook verify token',
                    obscureText: true,
                    suffixTooltip: 'Chuỗi bảo mật tùy chọn do bạn tự đặt, dùng khi Meta xác minh webhook. Phải khớp giữa CRM và cấu hình Meta App. Token này được gửi lên cloud backend để xác thực webhook.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _instagramAppSecretController,
                    label: 'App Secret',
                    hint: 'Meta App Secret',
                    obscureText: true,
                    suffixTooltip: 'Lấy từ Meta for Developers (cùng App với Facebook Messenger). Được gửi lên cloud backend (mã hoá khi lưu) để xác thực chữ ký webhook — đây là ngoại lệ duy nhất, các thông tin khác vẫn lưu local.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _instagramAccessTokenController,
                    label: 'Access token',
                    hint: 'IGQ...',
                    obscureText: true,
                    suffixTooltip: 'Page Access Token (hoặc Instagram Access Token) cấp cho tài khoản Instagram Professional đã liên kết Page. Token này chỉ lưu ở backend local, dùng để gửi tin nhắn trực tiếp tới Graph API.',
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
            value: _instagramEnforce24hWindow,
            onChanged: (value) =>
                setState(() => _instagramEnforce24hWindow = value != false),
            title: Row(
              children: [
                const Flexible(child: Text('Áp dụng cửa sổ phản hồi 24h (Messenger Platform Policy)')),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Instagram Messaging dùng chung chính sách cửa sổ phản hồi 24h với Facebook Messenger Platform.',
                  child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          const _CapabilityRow(
            icon: Icons.verified_user_outlined,
            label:
                'Chỉ dùng Instagram Messaging API chính thức (Meta Graph API), không dùng cookie cá nhân',
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
            onPressed: () => _saveInstagramAccount(notifier),
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _editingAccountId == null
                  ? 'Lưu tài khoản Instagram mới'
                  : 'Cập nhật tài khoản Instagram',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE1306C),
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
      _instagramEnabled = false;
      _instagramEnforce24hWindow = true;
      _instagramAccountNameController.clear();
      _instagramAccountIdController.clear();
      _instagramAppIdController.clear();
      _instagramVerifyTokenController.clear();
      _instagramAppSecretController.clear();
      _instagramAccessTokenController.clear();
      _showForm = true;
    });
  }

  void _startEdit(InstagramSettingsState account) {
    setState(() {
      _editingAccountId = account.accountId;
      _editingCloudId = account.cloudId;
      _instagramEnabled = account.enabled;
      _instagramEnforce24hWindow = account.enforce24hWindow;
      _instagramAccountNameController.text = account.accountName;
      _instagramAccountIdController.text = account.accountId;
      _instagramAppIdController.text = account.appId;
      _instagramVerifyTokenController.text = account.verifyToken;
      _instagramAppSecretController.text = account.appSecret;
      _instagramAccessTokenController.text = account.accessToken;
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

  InstagramSettingsState _readInstagramSettings() {
    return InstagramSettingsState(
      enabled: _instagramEnabled,
      accountName: _instagramAccountNameController.text.trim(),
      accountId: _instagramAccountIdController.text.trim(),
      appId: _instagramAppIdController.text.trim(),
      webhookCallbackUrl: _cloudWebhookUrl,
      verifyToken: _instagramVerifyTokenController.text.trim(),
      appSecret: _instagramAppSecretController.text.trim(),
      accessToken: _instagramAccessTokenController.text.trim(),
      enforce24hWindow: _instagramEnforce24hWindow,
      cloudId: _editingCloudId,
    );
  }

  Future<void> _saveInstagramAccount(
    WorkflowAutomationNotifier notifier,
  ) async {
    await notifier.saveInstagramAccount(_readInstagramSettings());
    if (!mounted) return;
    if (ref.read(workflowAutomationProvider).errorText == null) {
      setState(() {
        _showForm = false;
        _editingAccountId = null;
        _editingCloudId = null;
      });
    }
  }

  Future<void> _confirmDeleteInstagramAccount(
    InstagramSettingsState account,
  ) async {
    final label = account.accountName.isNotEmpty
        ? account.accountName
        : account.accountId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Xoá tài khoản Instagram',
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
          'Bạn có chắc chắn muốn xoá tài khoản Instagram "$label" khỏi CRM không? CRM sẽ ngừng nhận và gửi tin nhắn cho tài khoản này.',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final accountId = account.accountId;
      await ref
          .read(workflowAutomationProvider.notifier)
          .deleteInstagramAccount(accountId);
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
