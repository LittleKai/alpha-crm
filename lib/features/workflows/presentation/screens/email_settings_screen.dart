import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../providers/workflow_automation_provider.dart';

class EmailSettingsScreen extends ConsumerStatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  ConsumerState<EmailSettingsScreen> createState() =>
      _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends ConsumerState<EmailSettingsScreen> {
  final _emailFromNameController = TextEditingController();
  final _emailFromAddressController = TextEditingController();
  final _emailSmtpHostController = TextEditingController();
  final _emailSmtpPortController = TextEditingController(text: '587');
  final _emailSmtpUsernameController = TextEditingController();
  final _emailSmtpPasswordController = TextEditingController();
  final _emailImapHostController = TextEditingController();
  final _emailImapPortController = TextEditingController(text: '993');
  final _emailImapUsernameController = TextEditingController();
  final _emailImapPasswordController = TextEditingController();

  bool _emailEnabled = false;
  bool _emailInboundEnabled = false;
  bool _emailSmtpSecure = false;
  bool _emailImapSecure = true;
  String _emailMode = 'transactional';
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
    _emailFromNameController.dispose();
    _emailFromAddressController.dispose();
    _emailSmtpHostController.dispose();
    _emailSmtpPortController.dispose();
    _emailSmtpUsernameController.dispose();
    _emailSmtpPasswordController.dispose();
    _emailImapHostController.dispose();
    _emailImapPortController.dispose();
    _emailImapUsernameController.dispose();
    _emailImapPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowAutomationProvider);
    final notifier = ref.read(workflowAutomationProvider.notifier);
    _hydrateControllers(state.email);

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
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.alternate_email_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Text(
                            'Email IMAP/SMTP',
                            style: AppTextStyles.pageTitle.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF3B82F6),
                                  Color(0xFF06B6D4),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'KÊNH EMAIL',
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
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Cấu hình Email IMAP/SMTP để gửi thông báo và nhận email vào CRM',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.isLoading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),

            // ── Error banner ────────────────────────────────────────
            if (state.errorText != null) ...[
              _StatusBanner(
                icon: Icons.warning_amber_rounded,
                text: state.errorText!,
                color: AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.m),
            ],

            // ── Overview info cards ─────────────────────────────────
            isMobile
                ? Column(
                    children: [
                      _InfoCard(
                        icon: Icons.mail_outlined,
                        iconColor: const Color(0xFF3B82F6),
                        title: 'Gửi email',
                        description: 'SMTP chuyển tiếp',
                      ),
                      const SizedBox(height: AppSpacing.s),
                      _InfoCard(
                        icon: Icons.inbox_outlined,
                        iconColor: const Color(0xFF06B6D4),
                        title: 'Nhận email',
                        description: 'IMAP inbox vào CRM',
                      ),
                      const SizedBox(height: AppSpacing.s),
                      _InfoCard(
                        icon: Icons.security_outlined,
                        iconColor: const Color(0xFF10B981),
                        title: 'Bảo mật',
                        description: 'TLS/SSL mã hóa',
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.mail_outlined,
                          iconColor: const Color(0xFF3B82F6),
                          title: 'Gửi email',
                          description: 'SMTP chuyển tiếp',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.inbox_outlined,
                          iconColor: const Color(0xFF06B6D4),
                          title: 'Nhận email',
                          description: 'IMAP inbox vào CRM',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.security_outlined,
                          iconColor: const Color(0xFF10B981),
                          title: 'Bảo mật',
                          description: 'TLS/SSL mã hóa',
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: AppSpacing.l),

            // ── Email settings card ─────────────────────────────────
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.alternate_email_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Email IMAP/SMTP',
                                style: AppTextStyles.sectionTitle.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Cấu hình máy chủ email để CRM có thể gửi thông báo (SMTP) và nhận email đến từ khách hàng (IMAP). Hỗ trợ Gmail, Outlook, và các dịch vụ email khác.',
                              child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _emailEnabled,
                        activeThumbColor: AppColors.primary,
                        onChanged: (value) =>
                            setState(() => _emailEnabled = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),
                  DropdownButtonFormField<String>(
                    initialValue: _emailMode,
                    decoration: InputDecoration(
                      labelText: 'Chế độ',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: Tooltip(
                        message: 'E2 (Transactional): Chỉ gửi email thông báo, nhắc nhở đến khách.\nE1 (Inbox): Email hai chiều — nhận email từ khách vào Live Chat CRM, đòi hỏi cấu hình thêm IMAP.',
                        child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'transactional',
                        child: Text('E2 - Chỉ gửi thông báo'),
                      ),
                      DropdownMenuItem(
                        value: 'inbox',
                        child: Text('E1 - Email thành hội thoại'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _emailMode = value;
                        _emailInboundEnabled = value == 'inbox';
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Row(
                    children: [
                      Expanded(
                        child: _TextField(
                          controller: _emailFromNameController,
                          label: 'Tên người gửi',
                          hint: 'Alpha CRM',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: _TextField(
                          controller: _emailFromAddressController,
                          label: 'Email gửi',
                          hint: 'care@example.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _TextField(
                          controller: _emailSmtpHostController,
                          label: 'SMTP host',
                          hint: 'smtp.example.com',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: _TextField(
                          controller: _emailSmtpPortController,
                          label: 'Port',
                          hint: '587',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _emailSmtpUsernameController,
                    label: 'SMTP username',
                    hint: 'care@example.com',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _emailSmtpPasswordController,
                    label: 'SMTP password / OAuth token',
                    hint: 'App password hoặc OAuth2 token',
                    obscureText: true,
                    suffixTooltip: 'Với Gmail: vào myaccount.google.com → Bảo mật → Mật khẩu ứng dụng để tạo App Password (cần bật xác minh 2 bước).\nVới Outlook: dùng App Password hoặc OAuth2 token.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _emailSmtpSecure,
                    onChanged: (value) =>
                        setState(() => _emailSmtpSecure = value == true),
                    title: Row(
                      children: [
                        const Flexible(child: Text('SMTP dùng SSL/TLS trực tiếp')),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Bật nếu SMTP server yêu cầu kết nối SSL/TLS ngay (thường port 465).\nTắt nếu dùng STARTTLS (thường port 587). Gmail mặc định dùng STARTTLS trên port 587.',
                          child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                        ),
                      ],
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _emailInboundEnabled,
                    onChanged: (value) => setState(() {
                      _emailInboundEnabled = value == true;
                      _emailMode =
                          _emailInboundEnabled ? 'inbox' : 'transactional';
                    }),
                    title: Row(
                      children: [
                        const Flexible(child: Text('Bật nhận IMAP để đưa email vào Live Chat')),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Khi bật, CRM sẽ kết nối IMAP để lấy email đến và hiển thị chúng như hội thoại trong Live Chat. Phù hợp cho kênh hỗ trợ khách qua email.',
                          child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                        ),
                      ],
                    ),
                  ),
                  if (_emailInboundEnabled) ...[
                    const SizedBox(height: AppSpacing.s),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _TextField(
                            controller: _emailImapHostController,
                            label: 'IMAP host',
                            hint: 'imap.example.com',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: _TextField(
                            controller: _emailImapPortController,
                            label: 'Port',
                            hint: '993',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s),
                    _TextField(
                      controller: _emailImapUsernameController,
                      label: 'IMAP username',
                      hint: 'care@example.com',
                    ),
                    const SizedBox(height: AppSpacing.s),
                    _TextField(
                      controller: _emailImapPasswordController,
                      label: 'IMAP password / OAuth token',
                      hint: 'App password hoặc OAuth2 token',
                      obscureText: true,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _emailImapSecure,
                      onChanged: (value) =>
                          setState(() => _emailImapSecure = value == true),
                      title: Row(
                        children: [
                          const Flexible(child: Text('IMAP dùng SSL/TLS')),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Bật nếu IMAP server yêu cầu SSL trực tiếp (thường port 993).\nGmail và hầu hết dịch vụ email lớn đều yêu cầu SSL trên port 993.',
                            child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.m),
                  ElevatedButton.icon(
                    onPressed: () =>
                        notifier.saveEmailSettings(_readEmailSettings()),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Lưu cấu hình Email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
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

  // ── Hydrate controllers (one-shot) ──────────────────────────────
  void _hydrateControllers(EmailSettingsState email) {
    if (_didHydrateControllers) return;
    if (email.fromAddress.isEmpty &&
        email.smtpHost.isEmpty &&
        email.imapHost.isEmpty) {
      return;
    }
    _didHydrateControllers = true;
    _emailEnabled = email.enabled;
    _emailMode = email.mode;
    _emailInboundEnabled = email.inboundEnabled;
    _emailSmtpSecure = email.smtpSecure;
    _emailImapSecure = email.imapSecure;
    _emailFromNameController.text = email.fromName;
    _emailFromAddressController.text = email.fromAddress;
    _emailSmtpHostController.text = email.smtpHost;
    _emailSmtpPortController.text = email.smtpPort.toString();
    _emailSmtpUsernameController.text = email.smtpUsername;
    _emailSmtpPasswordController.text = email.smtpPassword;
    _emailImapHostController.text = email.imapHost;
    _emailImapPortController.text = email.imapPort.toString();
    _emailImapUsernameController.text = email.imapUsername;
    _emailImapPasswordController.text = email.imapPassword;
  }

  // ── Read form → state model ─────────────────────────────────────
  EmailSettingsState _readEmailSettings() {
    return EmailSettingsState(
      enabled: _emailEnabled,
      mode: _emailMode,
      fromName: _emailFromNameController.text.trim(),
      fromAddress: _emailFromAddressController.text.trim(),
      smtpHost: _emailSmtpHostController.text.trim(),
      smtpPort: int.tryParse(_emailSmtpPortController.text.trim()) ?? 587,
      smtpSecure: _emailSmtpSecure,
      smtpUsername: _emailSmtpUsernameController.text.trim(),
      smtpPassword: _emailSmtpPasswordController.text.trim(),
      inboundEnabled: _emailInboundEnabled,
      imapHost: _emailImapHostController.text.trim(),
      imapPort: int.tryParse(_emailImapPortController.text.trim()) ?? 993,
      imapSecure: _emailImapSecure,
      imapUsername: _emailImapUsernameController.text.trim(),
      imapPassword: _emailImapPasswordController.text.trim(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Private helper widgets
// ═══════════════════════════════════════════════════════════════════

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.06),
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: iconColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: AppSpacing.borderRadiusS,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
