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

class WebchatSettingsScreen extends ConsumerStatefulWidget {
  const WebchatSettingsScreen({super.key});

  @override
  ConsumerState<WebchatSettingsScreen> createState() =>
      _WebchatSettingsScreenState();
}

class _WebchatSettingsScreenState extends ConsumerState<WebchatSettingsScreen> {
  static const _accentColor = Color(0xFF4F46E5);
  static const _embedScriptUrl =
      'https://alpha-studio-backend.fly.dev/webchat/widget.js';

  final _widgetNameController = TextEditingController();
  final _welcomeMessageController = TextEditingController();
  final _primaryColorController = TextEditingController(text: '#4F46E5');
  final _siteLabelController = TextEditingController();
  bool _widgetEnabled = false;
  bool _showForm = false;
  String? _editingWidgetId;
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
    _widgetNameController.dispose();
    _welcomeMessageController.dispose();
    _primaryColorController.dispose();
    _siteLabelController.dispose();
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

            // ── Connected widgets list ─────────────────────────────────
            _buildWidgetListCard(state.webchatWidgets),
            const SizedBox(height: AppSpacing.l),

            // ── Add / edit form ───────────────────────────────────────
            if (_showForm)
              _buildWebchatSettingsCard(notifier)
            else
              OutlinedButton.icon(
                onPressed: _startAdd,
                icon: const Icon(Icons.add),
                label: const Text('Thêm widget Webchat mới'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accentColor,
                  side: const BorderSide(color: _accentColor),
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
                    Icons.forum_outlined,
                    color: _accentColor,
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Flexible(
                    child: Text(
                      'Webchat Widget',
                      style: AppTextStyles.pageTitle.copyWith(
                        color: _accentColor,
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
                      color: _accentColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'EMBED WIDGET',
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
          'Nhúng widget chat trực tiếp lên website để nhận và trả lời tin nhắn khách truy cập qua CRM',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // ─── Overview section ────────────────────────────────────────────────

  Widget _buildOverviewSection(bool isMobile) {
    const cards = [
      _InfoCard(
        icon: Icons.code_outlined,
        iconColor: Color(0xFF10B981),
        title: 'Không cần cài đặt',
        subtitle: 'Chỉ cần dán 1 dòng script vào website, không cần app hay SDK',
      ),
      _InfoCard(
        icon: Icons.bolt_outlined,
        iconColor: Color(0xFFF59E0B),
        title: 'Realtime 2 chiều',
        subtitle: 'Khách truy cập và nhân viên trao đổi tin nhắn theo thời gian thực',
      ),
      _InfoCard(
        icon: Icons.palette_outlined,
        iconColor: _accentColor,
        title: 'Tuỳ biến giao diện',
        subtitle: 'Đổi tên hiển thị, lời chào và màu chủ đạo cho từng widget',
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

  // ─── Connected widgets list ────────────────────────────────────────────

  Widget _buildWidgetListCard(List<WebchatSettingsState> widgets) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Widget Webchat đã tạo (${widgets.length})',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.m),
          if (widgets.isEmpty)
            Text(
              'Chưa có widget Webchat nào. Nhấn "Thêm widget Webchat mới" bên dưới để bắt đầu.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            for (int i = 0; i < widgets.length; i++) ...[
              _buildWidgetRow(widgets[i]),
              if (i < widgets.length - 1) const SizedBox(height: AppSpacing.s),
            ],
        ],
      ),
    );
  }

  Widget _buildWidgetRow(WebchatSettingsState widget) {
    final label = widget.widgetName.isNotEmpty
        ? widget.widgetName
        : widget.widgetId;
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
              color: _accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_outlined,
              color: _accentColor,
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
                        color: widget.enabled
                            ? AppColors.success
                            : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.enabled
                          ? 'Đang hoạt động (Widget ID: ${widget.widgetId})'
                          : 'Đã tắt (Widget ID: ${widget.widgetId})',
                      style: AppTextStyles.caption.copyWith(
                        color: widget.enabled
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
            tooltip: 'Sao chép mã nhúng',
            icon: const Icon(Icons.integration_instructions_outlined, size: 20),
            onPressed: () => _copyEmbedSnippet(widget.widgetId),
          ),
          IconButton(
            tooltip: 'Chỉnh sửa',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _startEdit(widget),
          ),
          IconButton(
            tooltip: 'Xoá',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
            onPressed: () => _confirmDeleteWidget(widget),
          ),
        ],
      ),
    );
  }

  void _copyEmbedSnippet(String widgetId) {
    final snippet =
        '<script src="$_embedScriptUrl" data-widget-id="$widgetId"></script>';
    Clipboard.setData(ClipboardData(text: snippet));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép mã nhúng widget.')),
    );
  }

  // ─── Main settings card ──────────────────────────────────────────────

  Widget _buildWebchatSettingsCard(WorkflowAutomationNotifier notifier) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.forum_outlined,
                color: _accentColor,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Webchat Widget',
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: _accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Tạo một widget chat để nhúng lên website. Sau khi lưu, dùng nút sao chép mã nhúng để lấy đoạn script dán vào trang.',
                      child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _widgetEnabled,
                activeThumbColor: _accentColor,
                onChanged: (value) => setState(() => _widgetEnabled = value),
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
            _editingWidgetId == null
                ? 'Thêm widget Webchat mới'
                : 'Đang chỉnh sửa widget đã tạo',
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
                    controller: _widgetNameController,
                    label: 'Tên hiển thị',
                    hint: 'Hỗ trợ trang chủ',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _siteLabelController,
                    label: 'Ghi chú website (tuỳ chọn)',
                    hint: 'giaiphapsangtao.com',
                    suffixTooltip: 'Nhãn tự do để bạn phân biệt widget này gắn cho website nào — không được hệ thống kiểm tra hay giới hạn.',
                  ),
                ],
              );
              final right = Column(
                children: [
                  _TextField(
                    controller: _welcomeMessageController,
                    label: 'Lời chào mở đầu',
                    hint: 'Xin chào! Chúng tôi có thể giúp gì cho bạn?',
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _TextField(
                    controller: _primaryColorController,
                    label: 'Màu chủ đạo (mã hex)',
                    hint: '#4F46E5',
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
          const _CapabilityRow(
            icon: Icons.public_outlined,
            label:
                'Khách truy cập chat trực tiếp qua trình duyệt, không cần tài khoản hay cookie cá nhân',
            iconColor: Color(0xFF10B981),
          ),
          const SizedBox(height: AppSpacing.s),
          const _CapabilityRow(
            icon: Icons.lock_outline,
            label:
                'Chỉ hỗ trợ nhắn tin văn bản (MVP), giới hạn tần suất theo IP để chống spam',
            iconColor: _accentColor,
          ),
          const SizedBox(height: AppSpacing.m),
          ElevatedButton.icon(
            onPressed: () => _saveWidget(notifier),
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _editingWidgetId == null
                  ? 'Lưu widget mới'
                  : 'Cập nhật widget',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
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
      _editingWidgetId = null;
      _editingCloudId = null;
      _widgetEnabled = false;
      _widgetNameController.clear();
      _welcomeMessageController.clear();
      _primaryColorController.text = '#4F46E5';
      _siteLabelController.clear();
      _showForm = true;
    });
  }

  void _startEdit(WebchatSettingsState widget) {
    setState(() {
      _editingWidgetId = widget.widgetId;
      _editingCloudId = widget.cloudId;
      _widgetEnabled = widget.enabled;
      _widgetNameController.text = widget.widgetName;
      _welcomeMessageController.text = widget.welcomeMessage;
      _primaryColorController.text = widget.primaryColorHex;
      _siteLabelController.text = widget.siteLabel;
      _showForm = true;
    });
  }

  void _cancelForm() {
    setState(() {
      _showForm = false;
      _editingWidgetId = null;
      _editingCloudId = null;
    });
  }

  WebchatSettingsState _readWebchatSettings() {
    return WebchatSettingsState(
      enabled: _widgetEnabled,
      widgetId: _editingWidgetId ?? '',
      widgetName: _widgetNameController.text.trim(),
      welcomeMessage: _welcomeMessageController.text.trim(),
      primaryColorHex: _primaryColorController.text.trim().isEmpty
          ? '#4F46E5'
          : _primaryColorController.text.trim(),
      siteLabel: _siteLabelController.text.trim(),
      cloudId: _editingCloudId,
    );
  }

  Future<void> _saveWidget(WorkflowAutomationNotifier notifier) async {
    await notifier.saveWebchatWidget(_readWebchatSettings());
    if (!mounted) return;
    if (ref.read(workflowAutomationProvider).errorText == null) {
      setState(() {
        _showForm = false;
        _editingWidgetId = null;
        _editingCloudId = null;
      });
    }
  }

  Future<void> _confirmDeleteWidget(WebchatSettingsState widget) async {
    final label = widget.widgetName.isNotEmpty
        ? widget.widgetName
        : widget.widgetId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Xoá widget Webchat',
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
          'Bạn có chắc chắn muốn xoá widget "$label" khỏi CRM không? Đoạn script đã nhúng trên website sẽ ngừng hoạt động.',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final widgetId = widget.widgetId;
      await ref
          .read(workflowAutomationProvider.notifier)
          .deleteWebchatWidget(widgetId);
      if (mounted && _editingWidgetId == widgetId) {
        setState(() {
          _showForm = false;
          _editingWidgetId = null;
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
