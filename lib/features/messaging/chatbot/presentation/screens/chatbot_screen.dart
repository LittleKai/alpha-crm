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

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final TextEditingController _promptController = TextEditingController();
  double _tempValue = 0.7;
  String _selectedModel = 'Gemini 1.5 Flash';

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _showCreatePlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chưa có thiết kế modal tạo kịch bản.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotProvider);
    final notifier = ref.read(chatbotProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

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
        if (state.activeTab == 0)
          AppButton(
            text: 'Tạo kịch bản mới',
            icon: Icons.add_rounded,
            onPressed: () => _showCreatePlaceholder(context),
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
              onPressed: () => _showCreatePlaceholder(context),
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
            value: _selectedModel,
            items: const [
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
                text: 'Tải lên tài liệu',
                icon: Icons.cloud_upload_outlined,
                variant: AppButtonVariant.outline,
                onPressed: () {
                  notifier.addKnowledgeDocument('Báo cáo sản phẩm Q3_2026.pdf');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Đã thêm tài liệu kiến thức: Báo cáo sản phẩm Q3_2026.pdf',
                      ),
                    ),
                  );
                },
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
