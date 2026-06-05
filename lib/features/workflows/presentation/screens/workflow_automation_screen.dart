import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/workflow_models.dart';
import '../../providers/workflow_automation_provider.dart';

class WorkflowAutomationScreen extends ConsumerStatefulWidget {
  const WorkflowAutomationScreen({super.key});

  @override
  ConsumerState<WorkflowAutomationScreen> createState() =>
      _WorkflowAutomationScreenState();
}

class _WorkflowAutomationScreenState
    extends ConsumerState<WorkflowAutomationScreen> {
  final _searchController = TextEditingController();
  final _n8nBaseUrlController = TextEditingController();
  final _n8nApiKeyController = TextEditingController();
  final _n8nWebhookController = TextEditingController();
  final _n8nCallbackController = TextEditingController();
  bool _n8nEnabled = false;
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
    _searchController.dispose();
    _n8nBaseUrlController.dispose();
    _n8nApiKeyController.dispose();
    _n8nWebhookController.dispose();
    _n8nCallbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowAutomationProvider);
    final notifier = ref.read(workflowAutomationProvider.notifier);
    _hydrateControllers(state.n8n);

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
      backgroundColor: AppColors.appBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(isLoading: state.isLoading),
            const SizedBox(height: AppSpacing.l),
            if (state.errorText != null) ...[
              _StatusBanner(
                icon: Icons.warning_amber_rounded,
                text: state.errorText!,
                color: AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.m),
            ],
            isMobile
                ? Column(
                    children: [
                      _buildN8nSettingsCard(notifier),
                      const SizedBox(height: AppSpacing.m),
                      const _FacebookCloudCard(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildN8nSettingsCard(notifier)),
                      const SizedBox(width: AppSpacing.m),
                      const SizedBox(width: 360, child: _FacebookCloudCard()),
                    ],
                  ),
            const SizedBox(height: AppSpacing.l),
            _FilterBar(
              searchController: _searchController,
              selectedCategory: state.selectedCategory,
              selectedChannel: state.selectedChannel,
              onSearchChanged: notifier.setSearchQuery,
              onCategoryChanged: notifier.setCategory,
              onChannelChanged: notifier.setChannel,
            ),
            const SizedBox(height: AppSpacing.m),
            _TemplateGrid(
              templates: state.filteredTemplates,
              isLoading: state.isLoading,
              onInstall: notifier.installTemplate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildN8nSettingsCard(WorkflowAutomationNotifier notifier) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.s),
              Text('n8n URL ngoài', style: AppTextStyles.sectionTitle),
              const Spacer(),
              Switch(
                value: _n8nEnabled,
                onChanged: (value) => setState(() => _n8nEnabled = value),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          _TextField(
            controller: _n8nBaseUrlController,
            label: 'Base URL',
            hint: 'https://n8n.example.com',
          ),
          const SizedBox(height: AppSpacing.s),
          _TextField(
            controller: _n8nApiKeyController,
            label: 'API key',
            hint: 'X-N8N-API-KEY',
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.s),
          _TextField(
            controller: _n8nWebhookController,
            label: 'Event webhook URL',
            hint: 'https://n8n.example.com/webhook/alpha-crm',
          ),
          const SizedBox(height: AppSpacing.s),
          _TextField(
            controller: _n8nCallbackController,
            label: 'Cloud relay callback URL',
            hint: 'https://alpha-studio-backend.fly.dev/api/crm/n8n/actions',
          ),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              OutlinedButton.icon(
                onPressed: () => notifier.testN8nConnection(_readN8nSettings()),
                icon: const Icon(Icons.cable_outlined),
                label: const Text('Test n8n'),
              ),
              ElevatedButton.icon(
                onPressed: () => notifier.saveN8nSettings(_readN8nSettings()),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Lưu cấu hình'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _hydrateControllers(N8nSettingsState settings) {
    if (_didHydrateControllers) return;
    if (settings.baseUrl.isEmpty &&
        settings.apiKey.isEmpty &&
        settings.eventWebhookUrl.isEmpty &&
        settings.callbackUrl.isEmpty) {
      return;
    }
    _didHydrateControllers = true;
    _n8nEnabled = settings.enabled;
    _n8nBaseUrlController.text = settings.baseUrl;
    _n8nApiKeyController.text = settings.apiKey;
    _n8nWebhookController.text = settings.eventWebhookUrl;
    _n8nCallbackController.text = settings.callbackUrl;
  }

  N8nSettingsState _readN8nSettings() {
    return N8nSettingsState(
      enabled: _n8nEnabled,
      baseUrl: _n8nBaseUrlController.text.trim(),
      apiKey: _n8nApiKeyController.text.trim(),
      eventWebhookUrl: _n8nWebhookController.text.trim(),
      callbackUrl: _n8nCallbackController.text.trim(),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isLoading;

  const _Header({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kho workflow mẫu', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tự động hóa CRM qua n8n, AI, Zalo và Facebook Page',
                style: AppTextStyles.body,
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
    );
  }
}

class _FacebookCloudCard extends StatelessWidget {
  const _FacebookCloudCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.facebook_outlined, color: AppColors.primary),
              SizedBox(width: AppSpacing.s),
              Text('Facebook Page API'),
            ],
          ),
          SizedBox(height: AppSpacing.m),
          _CapabilityRow(
            icon: Icons.cloud_done_outlined,
            label: 'Page token lưu ở cloud backend',
          ),
          SizedBox(height: AppSpacing.s),
          _CapabilityRow(
            icon: Icons.webhook_outlined,
            label: 'Webhook Meta cần public cloud URL',
          ),
          SizedBox(height: AppSpacing.s),
          _CapabilityRow(
            icon: Icons.block_outlined,
            label: 'Không dùng cookie hoặc profile cá nhân',
          ),
        ],
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CapabilityRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
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

  const _TextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
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
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final WorkflowTemplateCategory? selectedCategory;
  final CrmChannel? selectedChannel;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<WorkflowTemplateCategory?> onCategoryChanged;
  final ValueChanged<CrmChannel?> onChannelChanged;

  const _FilterBar({
    required this.searchController,
    required this.selectedCategory,
    required this.selectedChannel,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onChannelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final children = [
      Expanded(
        flex: 2,
        child: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Tìm workflow, tag, kênh...',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: onSearchChanged,
        ),
      ),
      const SizedBox(width: AppSpacing.s, height: AppSpacing.s),
      Expanded(
        child: DropdownButtonFormField<WorkflowTemplateCategory?>(
          key: ValueKey(selectedCategory?.apiValue ?? 'all-categories'),
          initialValue: selectedCategory,
          decoration: const InputDecoration(
            labelText: 'Nhóm',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tất cả')),
            ...WorkflowTemplateCategory.values.map(
              (category) => DropdownMenuItem(
                value: category,
                child: Text(category.label),
              ),
            ),
          ],
          onChanged: onCategoryChanged,
        ),
      ),
      const SizedBox(width: AppSpacing.s, height: AppSpacing.s),
      Expanded(
        child: DropdownButtonFormField<CrmChannel?>(
          key: ValueKey(selectedChannel?.apiValue ?? 'all-channels'),
          initialValue: selectedChannel,
          decoration: const InputDecoration(
            labelText: 'Kênh',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tất cả')),
            ...CrmChannel.values.map(
              (channel) =>
                  DropdownMenuItem(value: channel, child: Text(channel.label)),
            ),
          ],
          onChanged: onChannelChanged,
        ),
      ),
    ];
    if (isMobile) {
      return Column(
        children: children
            .map(
              (child) => child is Expanded
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s),
                      child: child.child,
                    )
                  : child,
            )
            .toList(),
      );
    }
    return Row(children: children);
  }
}

class _TemplateGrid extends StatelessWidget {
  final List<WorkflowTemplate> templates;
  final bool isLoading;
  final ValueChanged<WorkflowTemplate> onInstall;

  const _TemplateGrid({
    required this.templates,
    required this.isLoading,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return const AppCard(
        child: Center(child: Text('Không có workflow phù hợp bộ lọc.')),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 1100 ? 3 : (width > 680 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: templates.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.m,
            mainAxisSpacing: AppSpacing.m,
            mainAxisExtent: crossAxisCount == 1 ? 300 : 320,
          ),
          itemBuilder: (context, index) {
            final template = templates[index];
            return _TemplateCard(
              template: template,
              isLoading: isLoading,
              onInstall: () => onInstall(template),
            );
          },
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final WorkflowTemplate template;
  final bool isLoading;
  final VoidCallback onInstall;

  const _TemplateCard({
    required this.template,
    required this.isLoading,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppSpacing.borderRadiusS,
                ),
                child: Icon(
                  _iconFor(template.iconName),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  template.name,
                  style: AppTextStyles.cardTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            template.description,
            style: AppTextStyles.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _Chip(label: template.category.label),
              _Chip(label: template.difficulty.label),
              ...template.supportedChannels.map(
                (channel) => _Chip(label: channel.label),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : onInstall,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Tạo workflow nháp'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'smart_toy':
        return Icons.smart_toy_outlined;
      case 'psychology':
        return Icons.psychology_outlined;
      case 'person_add':
        return Icons.person_add_alt_outlined;
      case 'schedule':
        return Icons.schedule_outlined;
      case 'notifications':
        return Icons.notifications_outlined;
      case 'facebook':
        return Icons.facebook_outlined;
      default:
        return Icons.account_tree_outlined;
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppSpacing.borderRadiusS,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Text(label, style: AppTextStyles.caption),
    );
  }
}
