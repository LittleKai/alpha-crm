import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _proxyController = TextEditingController();
  final _minDelayController = TextEditingController();
  final _maxDelayController = TextEditingController();
  final _chatbotDelayController = TextEditingController(text: '5');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider).settings;
      _proxyController.text = settings.proxy;
      _minDelayController.text = settings.minDelay.toString();
      _maxDelayController.text = settings.maxDelay.toString();
    });
  }

  @override
  void dispose() {
    _proxyController.dispose();
    _minDelayController.dispose();
    _maxDelayController.dispose();
    _chatbotDelayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final connectedCount = state.accounts
        .where((account) => account.isConnected)
        .length;

    if (state.isSaved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã lưu cài đặt.')));
        notifier.resetSavedState();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: AppSpacing.l),
            _AccountCard(
              proxyController: _proxyController,
              connectedCount: connectedCount,
              onProxyChanged: notifier.updateProxy,
              onAddAccount: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chưa triển khai đăng nhập QR thật.'),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.m),
            _TimeSettingsCard(
              minDelayController: _minDelayController,
              maxDelayController: _maxDelayController,
              chatbotDelayController: _chatbotDelayController,
              isLoading: state.isLoading,
              errorText: state.errorText,
              onMinDelayChanged: (value) =>
                  notifier.updateMinDelay(int.tryParse(value) ?? 0),
              onMaxDelayChanged: (value) =>
                  notifier.updateMaxDelay(int.tryParse(value) ?? 0),
              onSave: notifier.saveSettings,
            ),
            const SizedBox(height: AppSpacing.m),
            _AdvancedCard(
              enabled: state.settings.autoApproveFriend,
              isLoading: state.isLoading,
              onChanged: notifier.updateAutoApproveFriend,
              onSave: notifier.saveSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.settings_outlined, color: AppColors.primary, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cài Đặt', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Quản lý tài khoản Zalo và cấu hình ứng dụng',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  final TextEditingController proxyController;
  final int connectedCount;
  final ValueChanged<String> onProxyChanged;
  final VoidCallback onAddAccount;

  const _AccountCard({
    required this.proxyController,
    required this.connectedCount,
    required this.onProxyChanged,
    required this.onAddAccount,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_none_outlined, size: 20),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  'Tài khoản Zalo',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              AppBadge(
                label: '$connectedCount đang kết nối',
                variant: connectedCount > 0
                    ? AppBadgeVariant.success
                    : AppBadgeVariant.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            'Kết nối nhiều tài khoản Zalo đồng thời. Mỗi tài khoản quét QR riêng, lưu phiên riêng, hoạt động độc lập.',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            'Proxy cho tài khoản mới (Tùy chọn)',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: proxyController,
            style: AppTextStyles.body,
            onChanged: onProxyChanged,
            decoration: const InputDecoration(
              hintText: 'VD: http://ip:port hoặc socks5://user:pass@ip:port',
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              text: 'Thêm tài khoản Zalo',
              icon: Icons.add,
              onPressed: onAddAccount,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeSettingsCard extends StatelessWidget {
  final TextEditingController minDelayController;
  final TextEditingController maxDelayController;
  final TextEditingController chatbotDelayController;
  final bool isLoading;
  final String? errorText;
  final ValueChanged<String> onMinDelayChanged;
  final ValueChanged<String> onMaxDelayChanged;
  final VoidCallback onSave;

  const _TimeSettingsCard({
    required this.minDelayController,
    required this.maxDelayController,
    required this.chatbotDelayController,
    required this.isLoading,
    this.errorText,
    required this.onMinDelayChanged,
    required this.onMaxDelayChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.access_time_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const Spacer(),
              Text('Cài đặt thời gian', style: AppTextStyles.sectionTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 720;
              final fields = [
                _NumberInput(
                  label: 'Delay tối thiểu (giây)',
                  controller: minDelayController,
                  onChanged: onMinDelayChanged,
                ),
                _NumberInput(
                  label: 'Delay tối đa (giây)',
                  controller: maxDelayController,
                  onChanged: onMaxDelayChanged,
                ),
              ];

              if (stack) {
                return Column(
                  children: [
                    fields[0],
                    const SizedBox(height: AppSpacing.m),
                    fields[1],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(child: fields[1]),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            width: 220,
            child: _NumberInput(
              label: 'Delay chatbot trả lời (giây)',
              controller: chatbotDelayController,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          const AppAlert(
            message:
                'Delay ngẫu nhiên 30-60s giúp hành vi giống người thật, tránh bị hạn chế tài khoản.',
            variant: AppAlertVariant.warning,
          ),
          if (errorText != null) ...[
            const SizedBox(height: AppSpacing.s),
            AppAlert(message: errorText!, variant: AppAlertVariant.error),
          ],
          const SizedBox(height: AppSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              text: 'Lưu cài đặt',
              icon: Icons.save_outlined,
              isLoading: isLoading,
              onPressed: onSave,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvancedCard extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final ValueChanged<bool> onChanged;
  final VoidCallback onSave;

  const _AdvancedCard({
    required this.enabled,
    required this.isLoading,
    required this.onChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.settings_suggest_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const Spacer(),
              Text(
                'Tính năng tự động nâng cao',
                style: AppTextStyles.sectionTitle,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          CheckboxListTile(
            value: enabled,
            onChanged: (value) => onChanged(value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'Tự động đồng ý kết bạn',
              style: AppTextStyles.bodyMedium,
            ),
            subtitle: Text(
              'Tự động chấp nhận lời mời kết bạn từ người lạ trong thời gian thực (realtime & offline check).',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              text: 'Lưu cài đặt',
              icon: Icons.save_outlined,
              isLoading: isLoading,
              onPressed: onSave,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const _NumberInput({
    required this.label,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppTextStyles.body,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
