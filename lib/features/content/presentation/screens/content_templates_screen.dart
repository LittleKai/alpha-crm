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
      backgroundColor: AppColors.appBackground,
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
        const Icon(
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
      onPressed: () => _showPlaceholder(
        'Modal thêm tin mẫu cần mockup xác nhận trước khi triển khai.',
      ),
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
        height: 278,
        child: AppEmptyState(
          icon: Icons.content_paste_outlined,
          title: 'Không có tin nhắn mẫu nào',
          description:
              'Hãy tạo tin mẫu đầu tiên để tiết kiệm thời gian soạn tin cho các chiến dịch gửi hàng loạt.',
          height: 230,
          actions: [
            AppButton(
              text: 'Tạo tin mẫu đầu tiên',
              icon: Icons.add_rounded,
              onPressed: () => _showPlaceholder(
                'Modal tạo tin mẫu cần mockup xác nhận trước khi triển khai.',
              ),
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
              _buildTemplateCard(filteredTemplates[index]),
        );
      },
    );
  }

  Widget _buildTemplateCard(MessageTemplate template) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            template.title,
            style: AppTextStyles.cardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
          const Divider(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: AppSpacing.s),
          Text(
            'Ngày tạo: ${DateFormat('dd/MM/yyyy').format(template.createdAt)}',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  void _showPlaceholder(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
