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
              const Icon(
                Icons.account_tree_outlined,
                color: Color(0xFFFF6D5A),
                size: 24,
              ),
              const SizedBox(width: AppSpacing.s),
              Text('n8n URL ngoài', style: AppTextStyles.sectionTitle),
              const Spacer(),
              Switch(
                value: _n8nEnabled,
                activeThumbColor: const Color(0xFFFF6D5A),
                activeTrackColor: const Color(0xFFFFD4CF),
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
                icon: const Icon(
                  Icons.cable_outlined,
                  color: Color(0xFFFF6D5A),
                ),
                label: const Text('Test n8n'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.border),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => notifier.saveN8nSettings(_readN8nSettings()),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Lưu cấu hình'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6D5A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Kho workflow mẫu', style: AppTextStyles.pageTitle),
                  const SizedBox(width: AppSpacing.s),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'PRO AUTOMATION',
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
                'Tự động hóa CRM qua n8n, AI, Zalo và Facebook Page',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
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
    );
  }
}

class _FacebookCloudCard extends StatelessWidget {
  const _FacebookCloudCard();

  @override
  Widget build(BuildContext context) {
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
              Text('Facebook Page API', style: AppTextStyles.sectionTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          const _CapabilityRow(
            icon: Icons.cloud_done_outlined,
            label: 'Page token lưu ở cloud backend',
            iconColor: Color(0xFF10B981),
          ),
          const SizedBox(height: AppSpacing.s),
          const _CapabilityRow(
            icon: Icons.webhook_outlined,
            label: 'Webhook Meta cần public cloud URL',
            iconColor: Color(0xFF6366F1),
          ),
          const SizedBox(height: AppSpacing.s),
          const _CapabilityRow(
            icon: Icons.block_outlined,
            label: 'Không dùng cookie hoặc profile cá nhân',
            iconColor: Color(0xFFEF4444),
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
    final iconTheme = _iconThemeFor(template.iconName);
    final bgColor = iconTheme['bg']!;
    final fgColor = iconTheme['fg']!;

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
                  color: bgColor,
                  borderRadius: AppSpacing.borderRadiusS,
                ),
                child: Icon(_iconFor(template.iconName), color: fgColor),
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
              _buildColorChip(template.category.label),
              _buildColorChip(template.difficulty.label),
              ...template.supportedChannels.map(
                (channel) => _buildColorChip(channel.label),
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

  Widget _buildColorChip(String label) {
    final style = _chipStyleFor(label);
    return _Chip(
      label: label,
      backgroundColor: style['bg'],
      textColor: style['text'],
      borderColor: style['border'],
    );
  }

  Map<String, Color> _iconThemeFor(String name) {
    switch (name) {
      case 'smart_toy':
        return {
          'bg': const Color(0xFFF5F3FF), // Purple 50
          'fg': const Color(0xFF8B5CF6), // Violet 500
        };
      case 'psychology':
        return {
          'bg': const Color(0xFFFDF2F8), // Pink 50
          'fg': const Color(0xFFEC4899), // Pink 500
        };
      case 'person_add':
        return {
          'bg': const Color(0xFFECFDF5), // Emerald 50
          'fg': const Color(0xFF10B981), // Emerald 500
        };
      case 'schedule':
        return {
          'bg': const Color(0xFFFFFBEB), // Amber 50
          'fg': const Color(0xFFF59E0B), // Amber 500
        };
      case 'notifications':
        return {
          'bg': const Color(0xFFFEF2F2), // Red 50
          'fg': const Color(0xFFEF4444), // Red 500
        };
      case 'facebook':
        return {
          'bg': const Color(0xFFEEF2FF), // Indigo 50
          'fg': const Color(0xFF3B82F6), // Blue 500
        };
      default:
        return {
          'bg': const Color(0xFFF0FDFA), // Teal 50
          'fg': const Color(0xFF14B8A6), // Teal 500
        };
    }
  }

  Map<String, Color> _chipStyleFor(String label) {
    switch (label) {
      // Categories
      case 'Bán hàng':
        return {
          'bg': const Color(0xFFECFDF5), // Emerald 50
          'text': const Color(0xFF047857), // Emerald 700
          'border': const Color(0xFFA7F3D0), // Emerald 200
        };
      case 'Quản lý':
        return {
          'bg': const Color(0xFFEFF6FF), // Blue 50
          'text': const Color(0xFF1D4ED8), // Blue 700
          'border': const Color(0xFFBFDBFE), // Blue 200
        };
      case 'Marketing':
        return {
          'bg': const Color(0xFFFDF4FF), // Fuchsia 50
          'text': const Color(0xFF86198F), // Fuchsia 700
          'border': const Color(0xFFF5D0FE), // Fuchsia 200
        };
      case 'Thông báo':
        return {
          'bg': const Color(0xFFFFF7ED), // Orange 50
          'text': const Color(0xFFC2410C), // Orange 700
          'border': const Color(0xFFFFEDD5), // Orange 200
        };
      case 'AI':
        return {
          'bg': const Color(0xFFF5F3FF), // Purple 50
          'text': const Color(0xFF6D28D9), // Purple 700
          'border': const Color(0xFFDDD6FE), // Purple 200
        };
      case 'Tích hợp':
        return {
          'bg': const Color(0xFFF0FDF4), // Green 50
          'text': const Color(0xFF15803D), // Green 700
          'border': const Color(0xFFBBF7D0), // Green 200
        };

      // Difficulty
      case 'Dễ':
        return {
          'bg': const Color(0xFFF0FDF4), // Green 50
          'text': const Color(0xFF166534), // Green 800
          'border': const Color(0xFFDCFCE7), // Green 100
        };
      case 'Trung bình':
        return {
          'bg': const Color(0xFFFFFBEB), // Amber 50
          'text': const Color(0xFF92400E), // Amber 800
          'border': const Color(0xFFFEF3C7), // Amber 100
        };
      case 'Nâng cao':
        return {
          'bg': const Color(0xFFFEF2F2), // Red 50
          'text': const Color(0xFF991B1B), // Red 800
          'border': const Color(0xFFFEE2E2), // Red 100
        };

      // Channels
      case 'Zalo cá nhân':
        return {
          'bg': const Color(0xFFE0F2FE), // Sky 50
          'text': const Color(0xFF0369A1), // Sky 700
          'border': const Color(0xFFBAE6FD), // Sky 200
        };
      case 'Zalo OA':
        return {
          'bg': const Color(0xFFF0F9FF), // Sky 50 (light)
          'text': const Color(0xFF0284C7), // Sky 600
          'border': const Color(0xFFE0F2FE), // Sky 100
        };
      case 'Facebook Page':
        return {
          'bg': const Color(0xFFEEF2FF), // Indigo 50
          'text': const Color(0xFF4338CA), // Indigo 700
          'border': const Color(0xFFC7D2FE), // Indigo 200
        };

      default:
        return {
          'bg': AppColors.surfaceMuted,
          'text': AppColors.textSecondary,
          'border': AppColors.borderSoft,
        };
    }
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
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;

  const _Chip({
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceMuted,
        borderRadius: AppSpacing.borderRadiusS,
        border: Border.all(color: borderColor ?? AppColors.borderSoft),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: textColor ?? AppColors.textSecondary,
        ),
      ),
    );
  }
}
