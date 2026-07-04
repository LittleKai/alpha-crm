import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../providers/workflow_automation_provider.dart';

class FacebookSettingsScreen extends ConsumerStatefulWidget {
  const FacebookSettingsScreen({super.key});

  @override
  ConsumerState<FacebookSettingsScreen> createState() =>
      _FacebookSettingsScreenState();
}

class _FacebookSettingsScreenState
    extends ConsumerState<FacebookSettingsScreen> {
  final _facebookPageNameController = TextEditingController();
  final _facebookPageIdController = TextEditingController();
  final _facebookAppIdController = TextEditingController();
  final _facebookWebhookController = TextEditingController();
  final _facebookVerifyTokenController = TextEditingController();
  final _facebookPageTokenController = TextEditingController();
  bool _facebookEnabled = false;
  bool _facebookEnforce24hWindow = true;
  bool _didHydrateControllers = false;

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
    _facebookWebhookController.dispose();
    _facebookVerifyTokenController.dispose();
    _facebookPageTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowAutomationProvider);
    final notifier = ref.read(workflowAutomationProvider.notifier);
    _hydrateControllers(state.facebook);

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
            // ── Header ──────────────────────────────────────────
            _buildHeader(state.isLoading),
            const SizedBox(height: AppSpacing.l),

            // ── Error banner ────────────────────────────────────
            if (state.errorText != null) ...[
              _StatusBanner(
                icon: Icons.warning_amber_rounded,
                text: state.errorText!,
                color: AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.m),
            ],

            // ── Overview info cards ─────────────────────────────
            _buildOverviewSection(isMobile),
            const SizedBox(height: AppSpacing.l),

            // ── Main settings card ──────────────────────────────
            _buildFacebookSettingsCard(notifier),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────

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

  // ─── Overview section ────────────────────────────────────────

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
        subtitle: 'Token lưu ở backend local',
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

  // ─── Main settings card ──────────────────────────────────────

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
            ],
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
                  _TextField(
                    controller: _facebookWebhookController,
                    label: 'Webhook callback URL',
                    hint: 'https://public-domain.example/webhooks/facebook',
                    suffixTooltip: 'URL công khai (HTTPS) mà Meta gửi sự kiện Messenger đến. Phải truy cập được từ internet. Nếu chạy local, dùng ngrok hoặc Cloudflare Tunnel.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _facebookVerifyTokenController,
                    label: 'Verify token',
                    hint: 'Meta webhook verify token',
                    obscureText: true,
                    suffixTooltip: 'Chuỗi bảo mật tùy chọn do bạn tự đặt. Meta sẽ gửi token này khi xác minh webhook. Phải khớp giữa CRM và cấu hình Meta App.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _facebookPageTokenController,
                    label: 'Page access token',
                    hint: 'EAAB...',
                    obscureText: true,
                    suffixTooltip: 'Lấy từ developers.facebook.com → App → Messenger → Access Tokens. Chọn Page và Generate Token. Nên dùng long-lived token.',
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
                'Token và verify token được lưu ở backend local, không lưu trong Flutter',
            iconColor: Color(0xFF6366F1),
          ),
          const SizedBox(height: AppSpacing.m),
          ElevatedButton.icon(
            onPressed: () =>
                notifier.saveFacebookSettings(_readFacebookSettings()),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu cấu hình Facebook Page'),
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

  // ─── State helpers ───────────────────────────────────────────

  void _hydrateControllers(FacebookSettingsState facebook) {
    if (_didHydrateControllers) return;
    if (facebook.pageId.isEmpty && facebook.pageAccessToken.isEmpty) {
      return;
    }
    _didHydrateControllers = true;
    _facebookEnabled = facebook.enabled;
    _facebookEnforce24hWindow = facebook.enforce24hWindow;
    _facebookPageNameController.text = facebook.pageName;
    _facebookPageIdController.text = facebook.pageId;
    _facebookAppIdController.text = facebook.appId;
    _facebookWebhookController.text = facebook.webhookCallbackUrl;
    _facebookVerifyTokenController.text = facebook.verifyToken;
    _facebookPageTokenController.text = facebook.pageAccessToken;
  }

  FacebookSettingsState _readFacebookSettings() {
    return FacebookSettingsState(
      enabled: _facebookEnabled,
      pageName: _facebookPageNameController.text.trim(),
      pageId: _facebookPageIdController.text.trim(),
      appId: _facebookAppIdController.text.trim(),
      webhookCallbackUrl: _facebookWebhookController.text.trim(),
      verifyToken: _facebookVerifyTokenController.text.trim(),
      pageAccessToken: _facebookPageTokenController.text.trim(),
      enforce24hWindow: _facebookEnforce24hWindow,
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Private helper widgets
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
