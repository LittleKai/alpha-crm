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

class FacebookSettingsScreen extends ConsumerStatefulWidget {
  const FacebookSettingsScreen({super.key});

  @override
  ConsumerState<FacebookSettingsScreen> createState() =>
      _FacebookSettingsScreenState();
}

class _FacebookSettingsScreenState
    extends ConsumerState<FacebookSettingsScreen> {
  static const _cloudWebhookUrl =
      'https://alpha-studio-backend.fly.dev/api/crm/facebook/webhook';

  final _facebookPageNameController = TextEditingController();
  final _facebookPageIdController = TextEditingController();
  final _facebookAppIdController = TextEditingController();
  final _facebookVerifyTokenController = TextEditingController();
  final _facebookAppSecretController = TextEditingController();
  final _facebookPageTokenController = TextEditingController();
  bool _facebookEnabled = false;
  bool _facebookEnforce24hWindow = true;
  bool _showForm = false;
  String? _editingPageId;
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
    _facebookPageNameController.dispose();
    _facebookPageIdController.dispose();
    _facebookAppIdController.dispose();
    _facebookVerifyTokenController.dispose();
    _facebookAppSecretController.dispose();
    _facebookPageTokenController.dispose();
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

            // ── Connected pages list ──────────────────────────────────
            _buildAccountListCard(state.facebookPages),
            const SizedBox(height: AppSpacing.l),

            // ── Add / edit form ───────────────────────────────────────
            if (_showForm)
              _buildFacebookSettingsCard(notifier)
            else
              OutlinedButton.icon(
                onPressed: _startAdd,
                icon: const Icon(Icons.add),
                label: const Text('Thêm Facebook Page mới'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1877F2),
                  side: const BorderSide(color: Color(0xFF1877F2)),
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
                    Icons.facebook_outlined,
                    color: Color(0xFF1877F2),
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Flexible(
                    child: Text(
                      'Facebook Page Messenger',
                      style: AppTextStyles.pageTitle.copyWith(
                        color: const Color(0xFF1877F2),
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
                        colors: [Color(0xFF1877F2), Color(0xFF42A5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'MESSENGER API',
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
          'Kết nối Facebook Page để nhận và gửi tin nhắn Messenger qua CRM',
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
        subtitle: 'Chỉ dùng Messenger Platform API',
      ),
      _InfoCard(
        icon: Icons.lock_outline,
        iconColor: Color(0xFF6366F1),
        title: 'Bảo mật cao',
        subtitle: 'Page token lưu local, App Secret gửi cloud để xác thực webhook',
      ),
      _InfoCard(
        icon: Icons.timer_outlined,
        iconColor: Color(0xFFF59E0B),
        title: 'Cửa sổ 24h',
        subtitle: 'Messenger reply window policy',
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

  // ─── Connected pages list ────────────────────────────────────────────

  Widget _buildAccountListCard(List<FacebookSettingsState> pages) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Facebook Page đã kết nối (${pages.length})',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.m),
          if (pages.isEmpty)
            Text(
              'Chưa có Facebook Page nào được kết nối. Nhấn "Thêm Facebook Page mới" bên dưới để bắt đầu.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            for (int i = 0; i < pages.length; i++) ...[
              _buildAccountRow(pages[i]),
              if (i < pages.length - 1) const SizedBox(height: AppSpacing.s),
            ],
        ],
      ),
    );
  }

  Widget _buildAccountRow(FacebookSettingsState page) {
    final label = page.pageName.isNotEmpty ? page.pageName : page.pageId;
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
              color: const Color(0xFF1877F2).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.facebook_outlined,
              color: Color(0xFF1877F2),
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
                        color: page.enabled
                            ? AppColors.success
                            : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      page.enabled
                          ? 'Đang hoạt động (Page ID: ${page.pageId})'
                          : 'Đã tắt (Page ID: ${page.pageId})',
                      style: AppTextStyles.caption.copyWith(
                        color: page.enabled
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
            onPressed: () => _startEdit(page),
          ),
          IconButton(
            tooltip: 'Xoá',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
            onPressed: () => _confirmDeleteFacebookPage(page),
          ),
        ],
      ),
    );
  }

  // ─── Main settings card ──────────────────────────────────────────────

  Widget _buildFacebookSettingsCard(WorkflowAutomationNotifier notifier) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.facebook_outlined,
                color: Color(0xFF1877F2),
                size: 24,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Facebook Page Messenger',
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: const Color(0xFF1877F2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Kết nối Facebook Page với CRM qua Messenger Platform API chính thức của Meta. Cho phép nhận và trả lời tin nhắn Messenger từ khách hàng trong Live Chat.',
                      child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _facebookEnabled,
                activeThumbColor: const Color(0xFF1877F2),
                onChanged: (value) =>
                    setState(() => _facebookEnabled = value),
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
            _editingPageId == null
                ? 'Thêm Facebook Page mới'
                : 'Đang chỉnh sửa Page đã kết nối',
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
                    controller: _facebookPageNameController,
                    label: 'Tên Page',
                    hint: 'Alpha CRM',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _facebookPageIdController,
                    label: 'Page ID',
                    hint: '1234567890',
                    suffixTooltip: 'Vào Facebook Page → Giới thiệu (About) → Miền bình luận để tìm Page ID, hoặc lấy từ URL trang Page của bạn.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _facebookAppIdController,
                    label: 'Facebook App ID',
                    hint: 'Meta App ID',
                    suffixTooltip: 'Tạo ứng dụng tại developers.facebook.com → My Apps → Create App. Chọn loại Business, thêm sản phẩm Messenger và Webhooks.',
                  ),
                ],
              );
              final right = Column(
                children: [
                  _ReadOnlyCopyField(
                    label: 'Webhook callback URL (dán vào Meta App)',
                    value: _cloudWebhookUrl,
                    tooltip: 'URL webhook cố định do cloud backend của Alpha CRM cung cấp. Dán URL này vào Meta App → Messenger → Webhooks. Không cần ngrok hay tunnel local.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _facebookVerifyTokenController,
                    label: 'Verify token',
                    hint: 'Meta webhook verify token',
                    obscureText: true,
                    suffixTooltip: 'Chuỗi bảo mật tùy chọn do bạn tự đặt. Meta sẽ gửi token này khi xác minh webhook. Phải khớp giữa CRM và cấu hình Meta App. Token này được gửi lên cloud backend để xác thực webhook.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _facebookAppSecretController,
                    label: 'App Secret',
                    hint: 'Meta App Secret',
                    obscureText: true,
                    suffixTooltip: 'Lấy từ developers.facebook.com → App → Settings → Basic → App Secret. Được gửi lên cloud backend (mã hoá khi lưu) để xác thực chữ ký (X-Hub-Signature-256) của mỗi webhook Meta gửi đến — đây là ngoại lệ duy nhất, các thông tin khác vẫn lưu local.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _facebookPageTokenController,
                    label: 'Page access token',
                    hint: 'EAAB...',
                    obscureText: true,
                    suffixTooltip: 'Lấy từ developers.facebook.com → App → Messenger → Access Tokens. Chọn Page và Generate Token. Nên dùng long-lived token. Token này chỉ lưu ở backend local, dùng để gửi tin nhắn trực tiếp tới Graph API.',
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
            value: _facebookEnforce24hWindow,
            onChanged: (value) =>
                setState(() => _facebookEnforce24hWindow = value != false),
            title: Row(
              children: [
                const Flexible(child: Text('Áp dụng cửa sổ phản hồi Messenger 24h')),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Messenger chỉ cho phép Page trả lời trong 24h kể từ tin nhắn cuối của khách. Sau 24h cần dùng Message Tag hoặc One-Time Notification. Bật để CRM tự động tuân thủ.',
                  child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          const _CapabilityRow(
            icon: Icons.verified_user_outlined,
            label:
                'Chỉ dùng Messenger Platform API chính thức, không dùng cookie cá nhân',
            iconColor: Color(0xFF10B981),
          ),
          const SizedBox(height: AppSpacing.s),
          const _CapabilityRow(
            icon: Icons.lock_outline,
            label:
                'Page access token và verify token lưu ở backend local; App Secret được gửi lên cloud backend (mã hoá) để xác thực chữ ký webhook',
            iconColor: Color(0xFF6366F1),
          ),
          const SizedBox(height: AppSpacing.m),
          ElevatedButton.icon(
            onPressed: () => _saveFacebookAccount(notifier),
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _editingPageId == null
                  ? 'Lưu Facebook Page mới'
                  : 'Cập nhật Facebook Page',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
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
      _editingPageId = null;
      _editingCloudId = null;
      _facebookEnabled = false;
      _facebookEnforce24hWindow = true;
      _facebookPageNameController.clear();
      _facebookPageIdController.clear();
      _facebookAppIdController.clear();
      _facebookVerifyTokenController.clear();
      _facebookAppSecretController.clear();
      _facebookPageTokenController.clear();
      _showForm = true;
    });
  }

  void _startEdit(FacebookSettingsState page) {
    setState(() {
      _editingPageId = page.pageId;
      _editingCloudId = page.cloudId;
      _facebookEnabled = page.enabled;
      _facebookEnforce24hWindow = page.enforce24hWindow;
      _facebookPageNameController.text = page.pageName;
      _facebookPageIdController.text = page.pageId;
      _facebookAppIdController.text = page.appId;
      _facebookVerifyTokenController.text = page.verifyToken;
      _facebookAppSecretController.text = page.appSecret;
      _facebookPageTokenController.text = page.pageAccessToken;
      _showForm = true;
    });
  }

  void _cancelForm() {
    setState(() {
      _showForm = false;
      _editingPageId = null;
      _editingCloudId = null;
    });
  }

  FacebookSettingsState _readFacebookSettings() {
    return FacebookSettingsState(
      enabled: _facebookEnabled,
      pageName: _facebookPageNameController.text.trim(),
      pageId: _facebookPageIdController.text.trim(),
      appId: _facebookAppIdController.text.trim(),
      webhookCallbackUrl: _cloudWebhookUrl,
      verifyToken: _facebookVerifyTokenController.text.trim(),
      appSecret: _facebookAppSecretController.text.trim(),
      pageAccessToken: _facebookPageTokenController.text.trim(),
      enforce24hWindow: _facebookEnforce24hWindow,
      cloudId: _editingCloudId,
    );
  }

  Future<void> _saveFacebookAccount(
    WorkflowAutomationNotifier notifier,
  ) async {
    await notifier.saveFacebookAccount(_readFacebookSettings());
    if (!mounted) return;
    if (ref.read(workflowAutomationProvider).errorText == null) {
      setState(() {
        _showForm = false;
        _editingPageId = null;
        _editingCloudId = null;
      });
    }
  }

  Future<void> _confirmDeleteFacebookPage(FacebookSettingsState page) async {
    final label = page.pageName.isNotEmpty ? page.pageName : page.pageId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Xoá Facebook Page',
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
          'Bạn có chắc chắn muốn xoá Facebook Page "$label" khỏi CRM không? CRM sẽ ngừng nhận và gửi tin nhắn Messenger cho Page này.',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final pageId = page.pageId;
      await ref
          .read(workflowAutomationProvider.notifier)
          .deleteFacebookAccount(pageId);
      if (mounted && _editingPageId == pageId) {
        setState(() {
          _showForm = false;
          _editingPageId = null;
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
