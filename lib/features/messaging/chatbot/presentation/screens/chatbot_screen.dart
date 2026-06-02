import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_alert.dart';
import '../../../../../shared/widgets/app_badge.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/app_empty_state.dart';
import '../../../../../shared/widgets/app_select_field.dart';
import '../../../../../shared/widgets/app_table.dart';
import '../../../../../shared/widgets/app_tabs.dart';
import '../../providers/chatbot_provider.dart';
import '../../../../auth/providers/crm_auth_provider.dart';
import '../../../../../shared/api/crm_cloud_api.dart';
import '../../../../zalo_integration/providers/zalo_integration_provider.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final TextEditingController _promptController = TextEditingController();
  double _tempValue = 0.7;
  String _selectedModel = 'Gemini 1.5 Flash';

  final TextEditingController _testMessageController = TextEditingController();
  String? _playgroundResponse;
  bool _isPlaying = false;
  String? _selectedAccountId;

  @override
  void dispose() {
    _promptController.dispose();
    _testMessageController.dispose();
    super.dispose();
  }

  Future<void> _sendTestMessage() async {
    final msg = _testMessageController.text.trim();
    if (msg.isEmpty) return;

    setState(() {
      _isPlaying = true;
      _playgroundResponse = null;
    });

    final response = await CrmCloudApi.post('/crm/chatbot/test', {
      'message': msg,
    });

    setState(() {
      _isPlaying = false;
    });

    if (response['success'] == true && response['data'] != null) {
      setState(() {
        _playgroundResponse = response['data']['text']?.toString();
      });
      ref.read(crmAuthProvider.notifier).refreshSubscription();
    } else {
      setState(() {
        _playgroundResponse =
            'Lỗi: ${response['message'] ?? "Không nhận được phản hồi từ AI."}';
      });
    }
  }

  Future<void> _showCreateRuleDialog(BuildContext context) async {
    final keywordController = TextEditingController();
    final responseController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tạo kịch bản chatbot'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keywordController,
                  decoration: const InputDecoration(
                    labelText: 'Từ khóa',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                TextField(
                  controller: responseController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung phản hồi',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(chatbotProvider.notifier)
                    .addRule(keywordController.text, responseController.text);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
    keywordController.dispose();
    responseController.dispose();
  }

  Future<void> _showAddKnowledgeDialog(
      BuildContext context, ChatbotNotifier notifier) async {
    final docController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Thêm tài liệu/kiến thức mới'),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: docController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Nhập nội dung kiến thức hoặc tên tài liệu',
                hintText: 'VD: Chính sách bảo hành: 1 đổi 1 trong vòng 30 ngày...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = docController.text.trim();
                if (text.isNotEmpty) {
                  await notifier.addKnowledgeDocument(text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã thêm kiến thức: $text')),
                    );
                  }
                }
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
    docController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotProvider);
    final notifier = ref.read(chatbotProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    // Watch connected accounts
    final zaloState = ref.watch(zaloIntegrationProvider);
    final connectedAccounts = zaloState.accounts;

    final String selectedId = _selectedAccountId ?? "";
    final String activeId = (selectedId == "" || connectedAccounts.any((acc) => acc.id == selectedId))
        ? selectedId
        : "";

    // Sync prompt value once
    if (_promptController.text.isEmpty && state.systemPrompt.isNotEmpty) {
      _promptController.text = state.systemPrompt;
      _tempValue = state.temperature;
      _selectedModel = state.aiModel;
    }

    final header = Row(
      children: [
        const Icon(
          Icons.smart_toy_outlined,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chatbot Tự Động', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Thiết lập kịch bản trả lời tự động bằng từ khóa hoặc sử dụng AI để chăm sóc khách hàng 24/7',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        SizedBox(
          width: 240,
          child: AppSelectField<String>(
            value: activeId,
            hintText: 'Chọn tài khoản...',
            items: [
              DropdownMenuItem(
                value: "",
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primarySoft,
                      child: const Icon(
                        Icons.group_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        'Tất cả tài khoản',
                        style: AppTextStyles.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              ...connectedAccounts.map((account) {
                final cleanLabel = account.label.replaceAll(RegExp(r'\s*\([^)]*\)$'), '');
                final avatarUrl = account.avatarUrl;
                return DropdownMenuItem(
                  value: account.id,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.surfaceMuted,
                        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                cleanLabel.isNotEmpty ? cleanLabel[0].toUpperCase() : 'A',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(
                          cleanLabel,
                          style: AppTextStyles.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            onChanged: (val) {
              setState(() {
                _selectedAccountId = val;
              });
            },
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        if (state.activeTab == 0)
          AppButton(
            text: 'Tạo kịch bản mới',
            icon: Icons.add_rounded,
            onPressed: () => _showCreateRuleDialog(context),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: AppSpacing.m),
            AppTabs(
              tabs: const [
                AppTabItem(
                  label: 'Kịch bản từ khóa',
                  icon: Icons.vpn_key_outlined,
                ),
                AppTabItem(
                  label: 'Trí tuệ nhân tạo (AI)',
                  icon: Icons.psychology_outlined,
                ),
                AppTabItem(
                  label: 'Tài liệu kiến thức',
                  icon: Icons.folder_open_outlined,
                ),
                AppTabItem(
                  label: 'Nhật ký phản hồi',
                  icon: Icons.history_edu_outlined,
                ),
              ],
              selectedIndex: state.activeTab,
              onTabSelected: notifier.setActiveTab,
            ),
            const SizedBox(height: AppSpacing.m),
            _buildTabContent(state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(ChatbotState state, ChatbotNotifier notifier) {
    switch (state.activeTab) {
      case 0:
        return _buildKeywordTab(state, notifier);
      case 1:
        return _buildAiTab(state, notifier);
      case 2:
        return _buildKnowledgeTab(state, notifier);
      case 3:
        return _buildLogsTab(state, notifier);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildKeywordTab(ChatbotState state, ChatbotNotifier notifier) {
    if (state.rules.isEmpty) {
      return SizedBox(
        height: 520,
        child: AppEmptyState(
          icon: Icons.smart_toy_outlined,
          title: 'Chưa có kịch bản chatbot',
          description:
              'Tạo kịch bản trả lời tự động dựa trên từ khóa. Khi khách hàng gửi tin nhắn chứa từ khóa, chatbot sẽ tự động trả lời.',
          height: 520,
          actions: [
            AppButton(
              text: 'Tạo kịch bản đầu tiên',
              icon: Icons.add_rounded,
              onPressed: () => _showCreateRuleDialog(context),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980 ? 2 : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.m,
            mainAxisSpacing: AppSpacing.m,
            mainAxisExtent: 180,
          ),
          itemCount: state.rules.length,
          itemBuilder: (context, index) {
            final rule = state.rules[index];
            return AppCard(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const AppBadge(
                            label: 'Từ khóa',
                            variant: AppBadgeVariant.info,
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Text(
                            '"${rule.keyword}"',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Switch(
                            value: rule.isActive,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) =>
                                notifier.toggleRuleStatus(rule.id),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                              size: 20,
                            ),
                            onPressed: () {
                              notifier.deleteRule(rule.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã xóa kịch bản.'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Expanded(
                    child: Text(
                      rule.response,
                      style: AppTextStyles.body.copyWith(fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  const Divider(height: 1, color: AppColors.borderSoft),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'Trạng thái: ${rule.isActive ? "Đang hoạt động" : "Tạm ngưng"}',
                    style: AppTextStyles.caption.copyWith(
                      color: rule.isActive
                          ? AppColors.successText
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAiTab(ChatbotState state, ChatbotNotifier notifier) {
    final authState = ref.watch(crmAuthProvider);
    final totalRemaining =
        authState.includedAiRemaining + authState.extraAiRemaining;
    final isExpired = authState.subscriptionStatus == 'expired';
    final hasNoQuota = totalRemaining <= 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CẤU HÌNH BOT TRÍ TUỆ NHÂN TẠO (AI)',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          const AppAlert(
            message:
                'Khi chế độ AI hoạt động, bot sẽ trả lời tự động dựa trên prompt hệ thống và kho tài liệu kiến thức nếu tin nhắn của khách hàng không khớp với bất kỳ từ khóa cố định nào.',
            variant: AppAlertVariant.info,
          ),
          const SizedBox(height: AppSpacing.m),
          Text('Mô hình ngôn ngữ AI sử dụng:', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.xs),
          AppSelectField<String>(
            value: const [
              'gcli-default',
              'Gemini 1.5 Flash',
              'Gemini 1.5 Pro',
              'GPT-4o mini',
              'Zalo AI Custom',
            ].contains(_selectedModel)
                ? _selectedModel
                : 'gcli-default',
            items: const [
              DropdownMenuItem(
                value: 'gcli-default',
                child: Text('Mặc định hệ thống'),
              ),
              DropdownMenuItem(
                value: 'Gemini 1.5 Flash',
                child: Text('Gemini 1.5 Flash (Nhanh & Tối ưu)'),
              ),
              DropdownMenuItem(
                value: 'Gemini 1.5 Pro',
                child: Text('Gemini 1.5 Pro (Thông minh & Đa nhiệm)'),
              ),
              DropdownMenuItem(
                value: 'GPT-4o mini',
                child: Text('GPT-4o mini'),
              ),
              DropdownMenuItem(
                value: 'Zalo AI Custom',
                child: Text('Zalo AI Custom Model'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedModel = val;
                });
              }
            },
          ),
          const SizedBox(height: AppSpacing.m),
          Text('System Prompt (Chỉ dẫn hệ thống):', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _promptController,
            maxLines: 4,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Chỉ định cách chatbot phản hồi khách hàng...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusS),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Độ sáng tạo (Temperature): ${_tempValue.toStringAsFixed(1)}',
                style: AppTextStyles.label,
              ),
              Text(
                _tempValue < 0.4
                    ? 'Chính xác/Nhất quán'
                    : _tempValue > 0.8
                    ? 'Sáng tạo/Linh hoạt'
                    : 'Cân bằng',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: _tempValue,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            activeColor: AppColors.primary,
            onChanged: (val) {
              setState(() {
                _tempValue = val;
              });
            },
          ),
          const SizedBox(height: AppSpacing.l),
          const Divider(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: AppSpacing.m),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              text: 'Lưu cài đặt AI',
              icon: Icons.save_outlined,
              onPressed: () {
                notifier.updateAiConfig(
                  _selectedModel,
                  _promptController.text,
                  _tempValue,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã lưu cấu hình AI Chatbot.')),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Text(
            'THỬ NGHIỆM AI PLAYGROUND',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thử nghiệm trực tiếp chỉ dẫn prompt và xem kết quả phản hồi của AI Chatbot.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          if (isExpired) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ Gói dịch vụ CRM của bạn đã hết hạn. Vui lòng gia hạn tài khoản để mở khóa sử dụng AI Chatbot.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.errorText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else if (hasNoQuota) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ Hạn mức AI Quota của bạn đã hết. Vui lòng di chuyển tới mục Đăng ký để mua thêm gói AI Top-up.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.warningText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Text('Hạn mức AI khả dụng: ', style: AppTextStyles.caption),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: hasNoQuota
                      ? AppColors.errorSoft
                      : AppColors.successSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalRemaining lượt',
                  style: AppTextStyles.caption.copyWith(
                    color: hasNoQuota
                        ? AppColors.errorText
                        : AppColors.successText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testMessageController,
                  enabled: !isExpired && !hasNoQuota && !_isPlaying,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText:
                        'Nhập câu hỏi test chatbot (ví dụ: tư vấn giá sản phẩm)...',
                    hintStyle: AppTextStyles.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: (isExpired || hasNoQuota || _isPlaying)
                    ? null
                    : _sendTestMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: _isPlaying
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
          if (_playgroundResponse != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI CHATBOT PHẢN HỒI:',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _playgroundResponse!,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKnowledgeTab(ChatbotState state, ChatbotNotifier notifier) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'TÀI LIỆU KIẾN THỨC NỀN TẢNG',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Tải lên các tài liệu để làm cơ sở tri thức giúp AI Chatbot trả lời thông tin chính xác về doanh nghiệp của bạn.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              AppButton(
                text: 'Thêm kiến thức',
                icon: Icons.add_rounded,
                variant: AppButtonVariant.outline,
                onPressed: () => _showAddKnowledgeDialog(context, notifier),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          const Divider(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: AppSpacing.s),
          state.knowledgeDocuments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(
                    child: Text(
                      'Chưa có tài liệu kiến thức nào.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.knowledgeDocuments.length,
                  itemBuilder: (context, index) {
                    final doc = state.knowledgeDocuments[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.s),
                      elevation: 0,
                      color: AppColors.surfaceMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.description,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        title: Text(
                          doc,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Đã cập nhật: ${DateFormat('dd/MM/yyyy').format(DateTime.now())} • Cỡ file: 1.2 MB',
                          style: AppTextStyles.caption,
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                          onPressed: () {
                            notifier.removeKnowledgeDocument(doc);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Đã xóa tài liệu: $doc')),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildLogsTab(ChatbotState state, ChatbotNotifier notifier) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NHẬT KÝ PHẢN HỒI CỦA BOT',
                  style: AppTextStyles.sectionTitle,
                ),
                if (state.logs.isNotEmpty)
                  AppButton(
                    text: 'Xóa nhật ký',
                    icon: Icons.delete_outline,
                    variant: AppButtonVariant.outline,
                    onPressed: () {
                      notifier.clearLogs();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã xóa toàn bộ nhật ký phản hồi.'),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          SizedBox(
            height: 350,
            child: AppTable(
              isEmpty: state.logs.isEmpty,
              emptyTitle: 'Chưa có lượt kích hoạt nào',
              emptyDescription:
                  'Lịch sử phản hồi tự động của chatbot sẽ được lưu trữ ở đây.',
              columns: const [
                AppTableColumn(label: 'Khách hàng', size: ColumnSize.M),
                AppTableColumn(label: 'Từ khóa kích hoạt', size: ColumnSize.S),
                AppTableColumn(label: 'Nội dung phản hồi', size: ColumnSize.L),
                AppTableColumn(label: 'Thời gian', size: ColumnSize.S),
                AppTableColumn(label: 'Trạng thái', size: ColumnSize.S),
              ],
              rows: state.logs.map((log) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(log.customerName, style: AppTextStyles.bodyMedium),
                    ),
                    DataCell(
                      AppBadge(
                        label: log.keyword,
                        variant: log.status == 'Thành công'
                            ? AppBadgeVariant.info
                            : AppBadgeVariant.neutral,
                      ),
                    ),
                    DataCell(
                      Text(
                        log.response,
                        style: AppTextStyles.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(
                      Text(
                        DateFormat('dd/MM HH:mm').format(log.timestamp),
                        style: AppTextStyles.caption,
                      ),
                    ),
                    DataCell(
                      AppBadge(
                        label: log.status,
                        variant: log.status == 'Thành công'
                            ? AppBadgeVariant.success
                            : AppBadgeVariant.error,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
