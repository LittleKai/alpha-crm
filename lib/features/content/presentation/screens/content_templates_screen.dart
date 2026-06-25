import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../mock/mock_messages.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_search_field.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../providers/templates_provider.dart';

class ContentTemplatesScreen extends ConsumerStatefulWidget {
  const ContentTemplatesScreen({super.key});

  @override
  ConsumerState<ContentTemplatesScreen> createState() =>
      _ContentTemplatesScreenState();
}

class _ContentTemplatesScreenState
    extends ConsumerState<ContentTemplatesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(templatesProvider).searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(templatesProvider);
    final notifier = ref.read(templatesProvider.notifier);
    final filteredTemplates = _filteredTemplates(state);

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          ResponsiveBreakpoints.isMobile(context) ? AppSpacing.m : AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.l),
            _buildToolbar(notifier),
            const SizedBox(height: AppSpacing.l),
            _buildContent(state, filteredTemplates),
          ],
        ),
      ),
    );
  }

  List<MessageTemplate> _filteredTemplates(TemplatesState state) {
    final query = state.searchQuery.toLowerCase();
    if (query.isEmpty) return state.templates;

    return state.templates.where((template) {
      return template.title.toLowerCase().contains(query) ||
          template.content.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.content_paste_outlined,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tin mẫu nhanh', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Quản lý các kịch bản và nội dung tin ngắn để chèn nhanh khi tạo chiến dịch gửi tin',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(TemplatesNotifier notifier) {
    final search = AppSearchField(
      hintText: 'Tìm kiếm tin mẫu...',
      controller: _searchController,
      onChanged: notifier.setSearchQuery,
    );
    final addButton = AppButton(
      text: 'Thêm tin mẫu',
      icon: Icons.add_rounded,
      onPressed: () => _showAddTemplateDialog(context, notifier),
    );

    if (ResponsiveBreakpoints.isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: AppSpacing.s),
          addButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: search),
        const SizedBox(width: AppSpacing.sm),
        addButton,
      ],
    );
  }

  Widget _buildContent(
    TemplatesState state,
    List<MessageTemplate> filteredTemplates,
  ) {
    final notifier = ref.read(templatesProvider.notifier);

    if (state.errorMessage != null) {
      return AppCard(
        height: 278,
        child: Center(
          child: Text(
            state.errorMessage!,
            style: AppTextStyles.body.copyWith(color: AppColors.errorText),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (state.templates.isEmpty) {
      return AppCard(
        child: AppEmptyState(
          icon: Icons.content_paste_outlined,
          title: 'Không có tin nhắn mẫu nào',
          description:
              'Hãy tạo tin mẫu đầu tiên để tiết kiệm thời gian soạn tin cho các chiến dịch gửi hàng loạt.',
          actions: [
            AppButton(
              text: 'Tạo tin mẫu đầu tiên',
              icon: Icons.add_rounded,
              onPressed: () => _showAddTemplateDialog(context, notifier),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.m,
            mainAxisSpacing: AppSpacing.m,
            mainAxisExtent: 190,
          ),
          itemCount: filteredTemplates.length,
          itemBuilder: (context, index) =>
              _buildTemplateCard(filteredTemplates[index], notifier),
        );
      },
    );
  }

  Widget _buildTemplateCard(
    MessageTemplate template,
    TemplatesNotifier notifier,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  template.title,
                  style: AppTextStyles.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 18,
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await notifier.deleteTemplate(template.id);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Đã xóa tin mẫu.')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Expanded(
            child: Text(
              template.content,
              style: AppTextStyles.body.copyWith(fontSize: 13),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Divider(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ngày tạo: ${DateFormat('dd/MM/yyyy').format(template.createdAt)}',
                  style: AppTextStyles.caption,
                ),
              ),
              if (template.isQuick)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                  ),
                  child: Text(
                    template.shortcut.isEmpty ? 'Quick' : template.shortcut,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTemplateDialog(
    BuildContext context,
    TemplatesNotifier notifier,
  ) async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final shortcutController = TextEditingController();
    var isQuick = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AppDialog(
          title: 'Thêm tin mẫu mới',
          icon: Icons.add_box_outlined,
          width: 460,
          actions: [
            AppDialogAction(
              text: 'Hủy',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            AppDialogAction(
              text: 'Lưu',
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                final title = titleController.text.trim();
                final content = contentController.text.trim();
                final rawShortcut = shortcutController.text.trim();
                final shortcut = rawShortcut.isEmpty
                    ? ''
                    : (rawShortcut.startsWith('/')
                          ? rawShortcut
                          : '/$rawShortcut');
                if (title.isNotEmpty && content.isNotEmpty) {
                  await notifier.addTemplate(
                    MessageTemplate(
                      id: '',
                      title: title,
                      content: content,
                      variables: const [],
                      createdAt: DateTime.now(),
                      shortcut: shortcut,
                      isQuick: isQuick,
                    ),
                  );
                }
                navigator.pop();
              },
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề tin mẫu',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: contentController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Nội dung tin nhắn',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: shortcutController,
                decoration: const InputDecoration(
                  labelText: 'Phím tắt',
                  hintText: '/1 hoặc /hello',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        );
      },
    );
    titleController.dispose();
    contentController.dispose();
    shortcutController.dispose();
  }
}
