import 'dart:io' show Platform, Directory, Process;
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/routing/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../mock/mock_accounts.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_provider.dart';
import '../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../../zalo_integration/data/zalo_integration_api.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _minDelayController = TextEditingController();
  final _maxDelayController = TextEditingController();
  final _chatbotDelayController = TextEditingController(text: '5');
  final _backendUrlController = TextEditingController();
  final _batchSizeController = TextEditingController();
  final _dailyLimitController = TextEditingController();
  final _cooldownController = TextEditingController();
  final _approvalThresholdController = TextEditingController();
  final _failureRateController = TextEditingController();
  final _stopReportController = TextEditingController();
  final _quietStartController = TextEditingController();
  final _quietEndController = TextEditingController();
  String? _defaultDownloadsPath;

  @override
  void initState() {
    super.initState();
    _resolveDefaultDownloadsPath();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider).settings;
      _minDelayController.text = settings.minDelay.toString();
      _maxDelayController.text = settings.maxDelay.toString();
      _backendUrlController.text = settings.zaloBackendBaseUrl;
      _batchSizeController.text = settings.maxBatchSize.toString();
      _dailyLimitController.text = settings.dailySendLimit.toString();
      _cooldownController.text = settings.perRecipientCooldownHours.toString();
      _approvalThresholdController.text = settings.humanApprovalThreshold
          .toString();
      _failureRateController.text = settings.maxFailureRatePercent.toString();
      _stopReportController.text = settings.stopOnReportCount.toString();
      _quietStartController.text = settings.quietHoursStart;
      _quietEndController.text = settings.quietHoursEnd;
      ref.read(zaloIntegrationProvider.notifier).checkConnection();

      // Tự động kiểm tra cập nhật khi mở trang Settings (chỉ trên Windows/Android)
      if (Platform.isWindows || Platform.isAndroid) {
        ref.read(updateProvider.notifier).checkForUpdates();
      }
    });
  }

  Future<void> _resolveDefaultDownloadsPath() async {
    try {
      if (!kIsWeb) {
        final dir = await getDownloadsDirectory();
        if (dir != null && mounted) {
          setState(() {
            _defaultDownloadsPath = '${dir.path}${Platform.pathSeparator}AlphaCRM';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _openDownloadFolder(String path) async {
    final resolvedPath = path.isNotEmpty ? path : _defaultDownloadsPath;
    if (resolvedPath != null && resolvedPath.isNotEmpty) {
      final dir = Directory(resolvedPath);
      if (await dir.exists()) {
        try {
          if (Platform.isWindows) {
            await Process.run('explorer.exe', [resolvedPath]);
          } else {
            final uri = Uri.file(resolvedPath);
            await launchUrl(uri);
          }
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _minDelayController.dispose();
    _maxDelayController.dispose();
    _chatbotDelayController.dispose();
    _backendUrlController.dispose();
    _batchSizeController.dispose();
    _dailyLimitController.dispose();
    _cooldownController.dispose();
    _approvalThresholdController.dispose();
    _failureRateController.dispose();
    _stopReportController.dispose();
    _quietStartController.dispose();
    _quietEndController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final zaloState = ref.watch(zaloIntegrationProvider);
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final isClient = kIsWeb || Platform.isAndroid || Platform.isIOS;
    final connectedCount = zaloState.accounts.length;

    if (state.isSaved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã lưu cài đặt.')));
        notifier.resetSavedState();
      });
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: AppSpacing.l),
            _AppearanceCard(
              themeMode: state.settings.appThemeMode,
              onChanged: notifier.setAppThemeMode,
            ),
            const SizedBox(height: AppSpacing.m),
            _AccountCard(
              connectedCount: connectedCount,
              accounts: zaloState.accounts,
              showAddButton: !isClient,
              onAddAccount: () => _showAddAccountQrDialog(context),
              onConfigureAccount: (account) =>
                  _showAccountSettingsDialog(context, account),
              onDeleteAccount: (account) =>
                  _confirmDeleteAccount(context, ref, account),
            ),
            const SizedBox(height: AppSpacing.m),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.download_for_offline_outlined,
                        color: Color(0xFF14B8A6),
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Text(
                        'Tải xuống và media cache',
                        style: AppTextStyles.sectionTitle,
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Thiết lập thư mục tải xuống tệp tin/media từ Live Chat và cấu hình giới hạn dung lượng bộ nhớ đệm cục bộ.',
                        child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextFormField(
                    key: ValueKey(state.settings.downloadFolder),
                    initialValue: state.settings.downloadFolder.isNotEmpty
                        ? state.settings.downloadFolder
                        : (_defaultDownloadsPath != null
                            ? 'Mặc định: $_defaultDownloadsPath'
                            : 'Mặc định (sẽ dùng thư mục Downloads hệ thống)'),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Thư mục tải xuống',
                      hintText: kIsWeb
                          ? 'Dùng thư mục tải xuống của trình duyệt'
                          : 'Thư mục Downloads mặc định',
                      suffixIcon: kIsWeb
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: 'Mở thư mục tải xuống hiện tại',
                                  child: IconButton(
                                    icon: const Icon(Icons.folder_open_outlined),
                                    onPressed: () => _openDownloadFolder(state.settings.downloadFolder),
                                  ),
                                ),
                                Tooltip(
                                  message: 'Chọn thư mục tải xuống riêng',
                                  child: IconButton(
                                    icon: const Icon(Icons.drive_file_move_outlined),
                                    onPressed: () async {
                                      final path = await FilePicker.platform
                                          .getDirectoryPath();
                                      if (path != null) {
                                        notifier.updateDownloadFolder(path);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: state
                              .settings
                              .liveChatMediaCacheMaxAgeDays
                              .toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Giữ cache (ngày)',
                          ),
                          onChanged: (value) =>
                              notifier.updateLiveChatMediaCacheMaxAgeDays(
                                int.tryParse(value) ?? 90,
                              ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: TextFormField(
                          initialValue: state.settings.liveChatMediaCacheMaxGb
                              .toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Giới hạn cache (GB)',
                          ),
                          onChanged: (value) =>
                              notifier.updateLiveChatMediaCacheMaxGb(
                                int.tryParse(value) ?? 20,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    kIsWeb
                        ? 'Web tải file trực tiếp, không mở tab mới. Vị trí lưu do trình duyệt quản lý.'
                        : 'Mặc định lưu vào Downloads/AlphaCRM. Media hội thoại được cache trên máy chạy Zalo bridge.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                      text: 'Lưu cài đặt media',
                      icon: Icons.save_outlined,
                      onPressed: notifier.saveSettings,
                    ),
                  ),
                ],
              ),
            ),
            if (!isClient) ...[
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
              _ZaloIntegrationCard(
                webhookPath: state.settings.zaloWebhookPath,
              ),
              const SizedBox(height: AppSpacing.m),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.security_outlined,
                          color: Color(0xFFEF4444),
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Text(
                          'Kiểm soát rủi ro Zalo',
                          style: AppTextStyles.sectionTitle,
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Thiết lập các quy tắc an toàn nâng cao (đồng ý gửi, thời gian im lặng, spintax, cooldown...) nhằm tối thiểu hóa rủi ro tài khoản bị khóa.',
                          child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Text(
                      'Cấu hình các cài đặt rủi ro, ngưỡng kiểm tra, quy tắc tuân thủ (consent, tương tác gần đây, spintax) và tự động hóa tài khoản để tránh bị khóa tài khoản Zalo.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        text: 'Cấu hình kiểm soát rủi ro Zalo',
                        icon: Icons.admin_panel_settings_outlined,
                        onPressed: () => _showRiskControlsDialog(context),
                      ),
                    ),
                  ],
                ),
              ),

            ],
            if (Platform.isWindows || Platform.isAndroid) ...[
              const SizedBox(height: AppSpacing.m),
              const _UpdateCard(),
            ],
          ],
        ),
      ),
    );
  }

  void _showRiskControlsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AppDialog(
          title: 'Cấu hình kiểm soát rủi ro Zalo',
          icon: Icons.admin_panel_settings_outlined,
          width: 800,
          child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(settingsProvider);
              final notifier = ref.read(settingsProvider.notifier);
              return _RiskControlsCard(
                settings: state.settings,
                batchSizeController: _batchSizeController,
                dailyLimitController: _dailyLimitController,
                cooldownController: _cooldownController,
                approvalThresholdController:
                    _approvalThresholdController,
                failureRateController: _failureRateController,
                stopReportController: _stopReportController,
                quietStartController: _quietStartController,
                quietEndController: _quietEndController,
                isLoading: state.isLoading,
                onChannelModeChanged: notifier.updateZaloChannelMode,
                onPersonalAutomationChanged:
                    notifier.updateAllowPersonalAccountAutomation,
                onProxyUsageChanged: notifier.updateAllowProxyUsage,
                onFriendAutomationChanged:
                    notifier.updateAllowFriendAutomation,
                onGroupAutomationChanged:
                    notifier.updateAllowGroupAutomation,
                onRequireConsentChanged:
                    notifier.updateRequireConsentProof,
                onRequireInteractionChanged:
                    notifier.updateRequireRecentInteraction,
                onDisableSpintaxChanged:
                    notifier.updateDisableSpintax,
                onRequireHumanApprovalChanged:
                    notifier.updateRequireHumanApproval,
                onBatchSizeChanged: (v) => notifier
                    .updateMaxBatchSize(int.tryParse(v) ?? 20),
                onDailyLimitChanged: (v) => notifier
                    .updateDailySendLimit(int.tryParse(v) ?? 100),
                onCooldownChanged: (v) =>
                    notifier.updatePerRecipientCooldownHours(
                      int.tryParse(v) ?? 24,
                    ),
                onApprovalThresholdChanged: (v) =>
                    notifier.updateHumanApprovalThreshold(
                      int.tryParse(v) ?? 20,
                    ),
                onFailureRateChanged: (v) =>
                    notifier.updateMaxFailureRatePercent(
                      int.tryParse(v) ?? 10,
                    ),
                onStopReportChanged: (v) => notifier
                    .updateStopOnReportCount(int.tryParse(v) ?? 1),
                onQuietStartChanged: notifier.updateQuietHoursStart,
                onQuietEndChanged: notifier.updateQuietHoursEnd,
                onSave: () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  await notifier.saveSettings();
                  if (context.mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Row(
                          children: const [
                            Icon(
                              Icons.check_circle,
                              color: Colors.white,
                            ),
                            SizedBox(width: AppSpacing.s),
                            Text('Lưu cài đặt rủi ro thành công!'),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showAddAccountQrDialog(BuildContext context) {
    final baseUrl = ref.read(settingsProvider).settings.zaloBackendBaseUrl;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _AddAccountQrDialog(baseUrl: baseUrl, ref: ref);
      },
    );
  }

  Future<void> _showAccountSettingsDialog(
    BuildContext context,
    ZaloConnectedAccount account,
  ) async {
    final nicknameController = TextEditingController(text: account.nickname);
    final proxyController = TextEditingController(text: account.proxy);
    var blockSeen = account.blockSeen;
    var blockTyping = account.blockTyping;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialog(
              title: 'Cấu hình ${account.label}',
              subtitle:
                  'Thiết lập tên hiển thị, proxy riêng và các tùy chọn bảo mật',
              icon: Icons.tune_rounded,
              width: 500,
              actions: [
                AppDialogAction(
                  text: 'Hủy',
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                AppDialogAction(
                  text: 'Lưu cấu hình',
                  variant: AppButtonVariant.primary,
                  onPressed: () async {
                    final success = await ref
                        .read(zaloIntegrationProvider.notifier)
                        .updateAccountSettings(
                          accountId: account.id,
                          nickname: nicknameController.text.trim(),
                          proxy: proxyController.text.trim(),
                          blockSeen: blockSeen,
                          blockTyping: blockTyping,
                        );
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Đã lưu cấu hình tài khoản.'
                              : 'Không thể lưu cấu hình tài khoản.',
                        ),
                      ),
                    );
                  },
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nicknameController,
                    decoration: InputDecoration(
                      labelText: 'Nickname hiển thị',
                      hintText: account.originalLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'Tên Zalo gốc: ${account.originalLabel}. Nếu đặt nickname, toàn bộ ứng dụng sẽ hiển thị nickname này.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextField(
                    controller: proxyController,
                    decoration: const InputDecoration(
                      labelText: 'Proxy riêng',
                      hintText: 'ip:port hoặc ip:port:user:pass',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'Proxy được lưu theo tài khoản trong local bot service. Việc áp dụng network proxy phụ thuộc khả năng hỗ trợ của adapter Zalo hiện tại.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  SwitchListTile(
                    value: blockSeen,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Chặn trạng thái đã xem'),
                    onChanged: (value) {
                      setDialogState(() => blockSeen = value);
                    },
                  ),
                  SwitchListTile(
                    value: blockTyping,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Chặn trạng thái đang nhập'),
                    onChanged: (value) {
                      setDialogState(() => blockTyping = value);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    nicknameController.dispose();
    proxyController.dispose();
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
    ZaloConnectedAccount account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AppDialog(
          title: 'Hủy liên kết tài khoản?',
          icon: Icons.warning_amber_rounded,
          width: 460,
          actions: [
            AppDialogAction(
              text: 'Bỏ qua',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            AppDialogAction(
              text: 'Xóa liên kết',
              variant: AppButtonVariant.destructive,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
          child: Text(
            'Bạn có chắc chắn muốn hủy liên kết tài khoản Zalo ${account.label}? Mọi thông tin đăng nhập trên thiết bị này sẽ bị xóa bỏ.',
            style: AppTextStyles.bodyMedium,
          ),
        );
      },
    );

    if (confirmed == true) {
      final success = await ref
          .read(zaloIntegrationProvider.notifier)
          .deleteAccount(account.id);
      if (!context.mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy liên kết tài khoản thành công.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể hủy liên kết tài khoản.')),
        );
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.settings_outlined, color: Color(0xFF6366F1), size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cài đặt', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Quản lý tài khoản Zalo và cấu hình ứng dụng',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => context.push(AppRoutes.systemLogs),
          icon: const Icon(Icons.bug_report_outlined),
          label: const Text('Xem lỗi hệ thống'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  final String themeMode;
  final ValueChanged<String> onChanged;

  const _AppearanceCard({required this.themeMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final selected = <String>{
      themeMode == 'dark' || themeMode == 'system' ? themeMode : 'light',
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.contrast_outlined,
                color: Color(0xFF8B5CF6),
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s),
              Text('Giao diện', style: AppTextStyles.sectionTitle),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Cấu hình chế độ hiển thị giao diện của ứng dụng (Sáng, Tối hoặc theo hệ thống).',
                child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'light',
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Sáng'),
              ),
              ButtonSegment(
                value: 'dark',
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Tối'),
              ),
              ButtonSegment(
                value: 'system',
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('Hệ thống'),
              ),
            ],
            selected: selected,
            onSelectionChanged: (values) {
              if (values.isNotEmpty) onChanged(values.first);
            },
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final int connectedCount;
  final List<ZaloConnectedAccount> accounts;
  final VoidCallback onAddAccount;
  final ValueChanged<ZaloConnectedAccount> onConfigureAccount;
  final ValueChanged<ZaloConnectedAccount> onDeleteAccount;
  final bool showAddButton;

  const _AccountCard({
    required this.connectedCount,
    required this.accounts,
    required this.onAddAccount,
    required this.onConfigureAccount,
    required this.onDeleteAccount,
    this.showAddButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_circle_outlined,
                color: AppColors.zaloBlue,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                'Tài khoản Zalo',
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Quản lý danh sách các tài khoản Zalo đang kết nối, trạng thái đồng bộ và cài đặt riêng cho từng tài khoản.',
                child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
              ),
              const Spacer(),
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

          if (accounts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            const Divider(),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Danh sách tài khoản đang hoạt động',
              style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.s),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: accounts.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.s),
              itemBuilder: (context, index) {
                final acc = accounts[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.s,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: AppSpacing.borderRadiusS,
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primarySoft,
                        backgroundImage: acc.avatarUrl.isNotEmpty
                            ? NetworkImage(acc.avatarUrl)
                            : null,
                        child: acc.avatarUrl.isEmpty
                            ? Text(
                                acc.label.isNotEmpty
                                    ? acc.label.substring(0, 1).toUpperCase()
                                    : 'Z',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              acc.label
                                  .replaceAll(RegExp(r'\s*\(\d+\)$'), '')
                                  .trim(),
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (acc.nickname.isNotEmpty &&
                                acc.originalLabel != acc.label) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Zalo: ${acc.originalLabel}',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: acc.isExpired
                                        ? AppColors.error
                                        : AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  acc.isExpired
                                      ? 'Mất kết nối'
                                      : acc.listenerRunning
                                          ? 'Đang lắng nghe'
                                          : 'Sẵn sàng',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10.5,
                                    color: acc.isExpired
                                        ? AppColors.error
                                        : AppColors.textSecondary,
                                    fontWeight: acc.isExpired
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (acc.isExpired)
                        IconButton(
                          tooltip: 'Tài khoản mất kết nối — xem nguyên nhân',
                          icon: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                          onPressed: () =>
                              _showDisconnectReasonDialog(context, acc),
                        ),
                      IconButton(
                        tooltip: 'Cấu hình tài khoản',
                        icon: Icon(
                          Icons.tune_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () => onConfigureAccount(acc),
                      ),
                      IconButton(
                        tooltip: 'Hủy liên kết tài khoản',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        onPressed: () => onDeleteAccount(acc),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          if (showAddButton) ...[
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
        ],
      ),
    );
  }

  void _showDisconnectReasonDialog(
    BuildContext context,
    ZaloConnectedAccount account,
  ) {
    final reason = account.disconnectReason.trim().isNotEmpty
        ? account.disconnectReason.trim()
        : 'Phiên đăng nhập Zalo đã bị ngắt. Vui lòng quét QR đăng nhập lại.';
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AppDialog(
          title: 'Tài khoản mất kết nối',
          icon: Icons.warning_amber_rounded,
          width: 500,
          actions: [
            AppDialogAction(
              text: 'Đóng',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            AppDialogAction(
              text: 'Đăng nhập lại',
              icon: Icons.qr_code_scanner_rounded,
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onAddAccount();
              },
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.label.replaceAll(RegExp(r'\s*\(\d+\)$'), '').trim(),
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(reason, style: AppTextStyles.body),
            ],
          ),
        );
      },
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
                color: Color(0xFFF97316),
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                'Cài đặt thời gian',
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Cấu hình khoảng thời gian trễ (delay) ngẫu nhiên giữa các hành động gửi tin tự động để phòng tránh bị Zalo chặn/checkpoint do gửi quá nhanh.',
                child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
              ),
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

class _ZaloIntegrationCard extends ConsumerStatefulWidget {
  final String webhookPath;

  const _ZaloIntegrationCard({
    required this.webhookPath,
  });

  @override
  ConsumerState<_ZaloIntegrationCard> createState() =>
      _ZaloIntegrationCardState();
}

class _ZaloIntegrationCardState extends ConsumerState<_ZaloIntegrationCard> {
  @override
  void initState() {
    super.initState();
    // Backend do supervisor tự quản lý; chỉ cần làm mới trạng thái Zalo khi mở
    // Cài đặt (thay cho nút "Kiểm tra kết nối" đã bỏ).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(zaloIntegrationProvider.notifier).checkConnection();
    });
  }

  @override
  Widget build(BuildContext context) {
    final integrationState = ref.watch(zaloIntegrationProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_outlined,
                color: Color(0xFF06B6D4),
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                'Trạng thái Zalo',
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Tình trạng tài khoản Zalo và tiến trình lắng nghe tin nhắn. Dịch vụ nền được khởi động & giám sát tự động.',
                child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Text('Webhook path: ', style: AppTextStyles.label),
              Text(
                widget.webhookPath,
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          if (integrationState.isConnected) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: AppSpacing.borderRadiusM,
                border: Border.all(color: AppColors.success),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service v${integrationState.serviceVersion ?? "?"}  •  Mode: ${integrationState.mode}',
                    style: AppTextStyles.bodyMedium,
                  ),
                  if (integrationState.accountType != null)
                    Text(
                      'Account: ${integrationState.accountLabel ?? integrationState.accountType} (${integrationState.accountType})',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  if (integrationState.listenerRunning)
                    Text(
                      'Listener: đang chạy',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  if (integrationState.lastEventAt != null)
                    Text(
                      'Last event: ${integrationState.lastEventAt}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ] else if (integrationState.errorText != null) ...[
            AppAlert(
              message: integrationState.errorText!,
              variant: AppAlertVariant.error,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.appBackground,
                borderRadius: AppSpacing.borderRadiusM,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      'Chưa có tài khoản Zalo nào kết nối. Hãy kết nối Zalo ở '
                      'màn hình tương ứng.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
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
}

class _RiskControlsCard extends StatelessWidget {
  final SystemSettings settings;
  final TextEditingController batchSizeController;
  final TextEditingController dailyLimitController;
  final TextEditingController cooldownController;
  final TextEditingController approvalThresholdController;
  final TextEditingController failureRateController;
  final TextEditingController stopReportController;
  final TextEditingController quietStartController;
  final TextEditingController quietEndController;
  final bool isLoading;
  final ValueChanged<ZaloChannelMode> onChannelModeChanged;
  final ValueChanged<bool> onPersonalAutomationChanged;
  final ValueChanged<bool> onProxyUsageChanged;
  final ValueChanged<bool> onFriendAutomationChanged;
  final ValueChanged<bool> onGroupAutomationChanged;
  final ValueChanged<bool> onRequireConsentChanged;
  final ValueChanged<bool> onRequireInteractionChanged;
  final ValueChanged<bool> onDisableSpintaxChanged;
  final ValueChanged<bool> onRequireHumanApprovalChanged;
  final ValueChanged<String> onBatchSizeChanged;
  final ValueChanged<String> onDailyLimitChanged;
  final ValueChanged<String> onCooldownChanged;
  final ValueChanged<String> onApprovalThresholdChanged;
  final ValueChanged<String> onFailureRateChanged;
  final ValueChanged<String> onStopReportChanged;
  final ValueChanged<String> onQuietStartChanged;
  final ValueChanged<String> onQuietEndChanged;
  final VoidCallback onSave;

  const _RiskControlsCard({
    required this.settings,
    required this.batchSizeController,
    required this.dailyLimitController,
    required this.cooldownController,
    required this.approvalThresholdController,
    required this.failureRateController,
    required this.stopReportController,
    required this.quietStartController,
    required this.quietEndController,
    required this.isLoading,
    required this.onChannelModeChanged,
    required this.onPersonalAutomationChanged,
    required this.onProxyUsageChanged,
    required this.onFriendAutomationChanged,
    required this.onGroupAutomationChanged,
    required this.onRequireConsentChanged,
    required this.onRequireInteractionChanged,
    required this.onDisableSpintaxChanged,
    required this.onRequireHumanApprovalChanged,
    required this.onBatchSizeChanged,
    required this.onDailyLimitChanged,
    required this.onCooldownChanged,
    required this.onApprovalThresholdChanged,
    required this.onFailureRateChanged,
    required this.onStopReportChanged,
    required this.onQuietStartChanged,
    required this.onQuietEndChanged,
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
                Icons.security_outlined,
                color: Color(0xFFEF4444),
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                'Kiểm soát rủi ro Zalo',
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Thiết lập các quy tắc an toàn nâng cao (đồng ý gửi, thời gian im lặng, spintax, cooldown...) nhằm tối thiểu hóa rủi ro tài khoản bị khóa.',
                child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),

          // Active safety switches
          _ChannelModeRow(
            currentMode: settings.zaloChannelMode,
            onChanged: (mode) {
              if (mode != null) {
                onChannelModeChanged(mode);
              }
            },
          ),
          _SwitchRow(
            label: 'Yêu cầu bằng chứng đồng ý',
            subtitle:
                'Không gửi tin nhắn nếu chưa có consent proof từ người nhận.',
            value: settings.requireConsentProof,
            onChanged: onRequireConsentChanged,
          ),
          _SwitchRow(
            label: 'Yêu cầu tương tác gần đây',
            subtitle:
                'Chỉ gửi khi người nhận đã tương tác với OA/Bot trong khoảng thời gian cho phép.',
            value: settings.requireRecentInteraction,
            onChanged: onRequireInteractionChanged,
          ),
          _SwitchRow(
            label: 'Tắt Spintax',
            subtitle: 'Không cho phép xoay vòng nội dung tin nhắn.',
            value: settings.disableSpintax,
            onChanged: onDisableSpintaxChanged,
          ),
          _SwitchRow(
            label: 'Yêu cầu duyệt thủ công',
            subtitle:
                'Chiến dịch vượt ngưỡng số lượng cần được duyệt trước khi gửi.',
            value: settings.requireHumanApproval,
            onChanged: onRequireHumanApprovalChanged,
          ),

          const Divider(height: AppSpacing.l),

          // Disabled unsafe toggles
          _DisabledSwitchRow(
            label: 'Tự động hóa tài khoản cá nhân',
            subtitle: settings.zaloChannelMode == ZaloChannelMode.officialOa
                ? 'Bị vô hiệu khi kênh Official OA đang chọn.'
                : 'Cho phép tự động hóa qua personal Zalo.',
            value: settings.allowPersonalAccountAutomation,
            isDisabled: settings.zaloChannelMode == ZaloChannelMode.officialOa,
            onChanged: onPersonalAutomationChanged,
          ),
          _DisabledSwitchRow(
            label: 'Sử dụng Proxy',
            subtitle:
                'Bị vô hiệu khi Official OA bật. Proxy có thể bị nhận diện là hành vi né tránh.',
            value: settings.allowProxyUsage,
            isDisabled: settings.zaloChannelMode == ZaloChannelMode.officialOa,
            onChanged: onProxyUsageChanged,
          ),
          _DisabledSwitchRow(
            label: 'Tự động kết bạn',
            subtitle:
                'Bị vô hiệu khi Official OA bật. Gửi lời mời kết bạn hàng loạt là rủi ro cao.',
            value: settings.allowFriendAutomation,
            isDisabled: settings.zaloChannelMode == ZaloChannelMode.officialOa,
            onChanged: onFriendAutomationChanged,
          ),
          _DisabledSwitchRow(
            label: 'Tự động nhóm',
            subtitle:
                'Bị vô hiệu khi Official OA bật. Tham gia/tạo/mời nhóm tự động là rủi ro cao.',
            value: settings.allowGroupAutomation,
            isDisabled: settings.zaloChannelMode == ZaloChannelMode.officialOa,
            onChanged: onGroupAutomationChanged,
          ),

          const Divider(height: AppSpacing.l),

          // Numeric fields
          Text(
            'Giới hạn & Ngưỡng',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.m),

          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 720;
              if (stack) {
                return Column(
                  children: [
                    _NumberInput(
                      label: 'Batch size tối đa',
                      controller: batchSizeController,
                      onChanged: onBatchSizeChanged,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _NumberInput(
                      label: 'Giới hạn gửi/ngày',
                      controller: dailyLimitController,
                      onChanged: onDailyLimitChanged,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _NumberInput(
                      label: 'Cooldown/người nhận (giờ)',
                      controller: cooldownController,
                      onChanged: onCooldownChanged,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _NumberInput(
                      label: 'Ngưỡng duyệt thủ công',
                      controller: approvalThresholdController,
                      onChanged: onApprovalThresholdChanged,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _NumberInput(
                      label: 'Tỷ lệ lỗi tối đa (%)',
                      controller: failureRateController,
                      onChanged: onFailureRateChanged,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _NumberInput(
                      label: 'Dừng khi bị báo cáo (lần)',
                      controller: stopReportController,
                      onChanged: onStopReportChanged,
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _NumberInput(
                          label: 'Batch size tối đa',
                          controller: batchSizeController,
                          onChanged: onBatchSizeChanged,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: _NumberInput(
                          label: 'Giới hạn gửi/ngày',
                          controller: dailyLimitController,
                          onChanged: onDailyLimitChanged,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: _NumberInput(
                          label: 'Cooldown/người nhận (giờ)',
                          controller: cooldownController,
                          onChanged: onCooldownChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberInput(
                          label: 'Ngưỡng duyệt thủ công',
                          controller: approvalThresholdController,
                          onChanged: onApprovalThresholdChanged,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: _NumberInput(
                          label: 'Tỷ lệ lỗi tối đa (%)',
                          controller: failureRateController,
                          onChanged: onFailureRateChanged,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: _NumberInput(
                          label: 'Dừng khi bị báo cáo (lần)',
                          controller: stopReportController,
                          onChanged: onStopReportChanged,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.m),

          // Quiet hours
          Text(
            'Giờ im lặng (không gửi)',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 400;
              if (stack) {
                return Column(
                  children: [
                    _TextInput(
                      label: 'Bắt đầu',
                      controller: quietStartController,
                      onChanged: onQuietStartChanged,
                      hintText: '21:00',
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _TextInput(
                      label: 'Kết thúc',
                      controller: quietEndController,
                      onChanged: onQuietEndChanged,
                      hintText: '08:00',
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _TextInput(
                      label: 'Bắt đầu',
                      controller: quietStartController,
                      onChanged: onQuietStartChanged,
                      hintText: '21:00',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: _TextInput(
                      label: 'Kết thúc',
                      controller: quietEndController,
                      onChanged: onQuietEndChanged,
                      hintText: '08:00',
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              text: 'Lưu cài đặt rủi ro',
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

class _SwitchRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: AppTextStyles.bodyMedium),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}

class _DisabledSwitchRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final bool isDisabled;
  final ValueChanged<bool> onChanged;

  const _DisabledSwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.isDisabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: SwitchListTile(
        value: value,
        onChanged: isDisabled ? null : (v) => onChanged(v),
        contentPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
            if (isDisabled)
              const AppBadge(
                label: 'Bị vô hiệu',
                variant: AppBadgeVariant.warning,
              ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _ChannelModeRow extends StatelessWidget {
  final ZaloChannelMode currentMode;
  final ValueChanged<ZaloChannelMode?> onChanged;

  const _ChannelModeRow({required this.currentMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kênh Zalo', style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Chọn kênh tích hợp: Personal Zalo hoặc Official OA.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.s),
          DropdownButtonFormField<ZaloChannelMode>(
            initialValue: currentMode,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: ZaloChannelMode.personalZca,
                child: Text('Personal Zalo'),
              ),
              DropdownMenuItem(
                value: ZaloChannelMode.officialOa,
                child: Text('Official OA'),
              ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _UpdateCard extends ConsumerWidget {
  const _UpdateCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateProvider);
    final notifier = ref.read(updateProvider.notifier);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.system_update_outlined,
                color: Color(0xFFD946EF),
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                'Cập nhật ứng dụng',
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Kiểm tra phiên bản hiện tại và cập nhật lên phiên bản mới nhất của ứng dụng CRM.',
                child: Icon(Icons.help_outline, size: 16, color: AppColors.iconMuted),
              ),
              const Spacer(),
              if (state.status == UpdateStatus.available)
                const AppBadge(
                  label: 'Có bản mới',
                  variant: AppBadgeVariant.warning,
                )
              else if (state.status == UpdateStatus.upToDate)
                const AppBadge(
                  label: 'Mới nhất',
                  variant: AppBadgeVariant.success,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),

          // Phiên bản hiện tại
          if (state.currentVersion.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppSpacing.borderRadiusS,
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    'Phiên bản hiện tại: ',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    'v${state.currentVersion}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

          // Trạng thái kiểm tra
          if (state.status == UpdateStatus.checking) ...[
            const SizedBox(height: AppSpacing.m),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.s),
                Text('Đang kiểm tra cập nhật...'),
              ],
            ),
          ],

          // Có bản cập nhật mới
          if (state.status == UpdateStatus.available ||
              state.status == UpdateStatus.downloading ||
              state.status == UpdateStatus.readyToInstall) ...[
            const SizedBox(height: AppSpacing.m),
            Container(
              padding: const EdgeInsets.all(AppSpacing.m),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: AppSpacing.borderRadiusM,
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.new_releases_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(
                          'Phiên bản mới: v${state.latestRelease?.version ?? "?"}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (state.latestRelease?.name != null &&
                      state.latestRelease!.name.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      state.latestRelease!.name,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (state.latestRelease?.body != null &&
                      state.latestRelease!.body.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: SingleChildScrollView(
                        child: Text(
                          state.latestRelease!.body,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (state.targetAsset != null) ...[
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      '${state.targetAsset!.name} (${state.targetAsset!.sizeFormatted})',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Tiến trình tải
          if (state.status == UpdateStatus.downloading) ...[
            const SizedBox(height: AppSpacing.m),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Đang tải xuống...', style: AppTextStyles.label),
                    Text(
                      '${(state.downloadProgress * 100).toStringAsFixed(0)}%',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: AppSpacing.borderRadiusS,
                  child: LinearProgressIndicator(
                    value: state.downloadProgress,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Sẵn sàng cài đặt
          if (state.status == UpdateStatus.readyToInstall) ...[
            const SizedBox(height: AppSpacing.m),
            const AppAlert(
              message:
                  'Tải xuống hoàn tất! Nhấn "Cài đặt ngay" để tiến hành cập nhật.',
              variant: AppAlertVariant.success,
            ),
          ],

          // Đang cài đặt
          if (state.status == UpdateStatus.installing) ...[
            const SizedBox(height: AppSpacing.m),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.s),
                Text('Đang mở trình cài đặt...'),
              ],
            ),
          ],

          // Đã cập nhật mới nhất
          if (state.status == UpdateStatus.upToDate) ...[
            const SizedBox(height: AppSpacing.m),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: AppSpacing.borderRadiusS,
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    'Ứng dụng đang ở phiên bản mới nhất.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.successText,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Lỗi
          if (state.status == UpdateStatus.error &&
              state.errorText != null) ...[
            const SizedBox(height: AppSpacing.m),
            AppAlert(message: state.errorText!, variant: AppAlertVariant.error),
          ],

          // Nút hành động
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              if (state.status == UpdateStatus.idle ||
                  state.status == UpdateStatus.upToDate ||
                  state.status == UpdateStatus.error)
                AppButton(
                  text: 'Kiểm tra cập nhật',
                  icon: Icons.refresh,
                  isLoading: state.status == UpdateStatus.checking,
                  onPressed: notifier.checkForUpdates,
                ),
              if (state.status == UpdateStatus.available &&
                  state.targetAsset != null)
                AppButton(
                  text: 'Tải xuống bản cập nhật',
                  icon: Icons.download_outlined,
                  onPressed: notifier.downloadUpdate,
                ),
              if (state.status == UpdateStatus.readyToInstall)
                AppButton(
                  text: 'Cài đặt ngay',
                  icon: Icons.install_desktop_outlined,
                  onPressed: notifier.installUpdate,
                ),
              if (state.hasUpdate ||
                  (state.status == UpdateStatus.available &&
                      state.targetAsset == null))
                AppButton(
                  text: 'Mở trang Releases',
                  icon: Icons.open_in_new,
                  variant: AppButtonVariant.outline,
                  onPressed: notifier.openReleasePage,
                ),
            ],
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

class _TextInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? hintText;

  const _TextInput({
    required this.label,
    required this.controller,
    this.onChanged,
    this.hintText,
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
          style: AppTextStyles.body,
          onChanged: onChanged,
          decoration: InputDecoration(hintText: hintText),
        ),
      ],
    );
  }
}

class _AddAccountQrDialog extends StatefulWidget {
  final String baseUrl;
  final WidgetRef ref;

  const _AddAccountQrDialog({required this.baseUrl, required this.ref});

  @override
  State<_AddAccountQrDialog> createState() => _AddAccountQrDialogState();
}

class _AddAccountQrDialogState extends State<_AddAccountQrDialog> {
  String? _sessionId;
  String? _qrUrl;
  String _status = 'loading'; // loading | pending | success | failed | timeout
  String? _errorText;
  Timer? _pollingTimer;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _startQrSession();
  }

  Future<void> _startQrSession() async {
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel();
    try {
      final api = ZaloIntegrationApi(baseUrl: widget.baseUrl);
      final result = await api.createQrSession();
      if (result['success'] == true && result['sessionId'] != null) {
        setState(() {
          _sessionId = result['sessionId']?.toString();
          _qrUrl = result['qrUrl']?.toString();
          _status = 'pending';
        });
        _startPolling();
        _startTimeoutTimer();
      } else {
        setState(() {
          _status = 'failed';
          _errorText =
              result['error']?.toString() ?? 'Không tạo được phiên quét QR.';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'failed';
        _errorText = e.toString();
      });
    }
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && _status == 'pending') {
        _pollingTimer?.cancel();
        setState(() {
          _status = 'timeout';
        });
      }
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_sessionId == null) return;
      try {
        final api = ZaloIntegrationApi(baseUrl: widget.baseUrl);
        final result = await api.checkSessionStatus(_sessionId!);
        if (result['success'] == true) {
          final status = result['status']?.toString();
          if (status == 'success') {
            timer.cancel();
            _timeoutTimer?.cancel();
            setState(() {
              _status = 'success';
            });
            // Reload provider accounts list
            widget.ref.read(zaloIntegrationProvider.notifier).checkConnection();

            // Auto close after delay
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
          } else if (status == 'failed') {
            timer.cancel();
            _timeoutTimer?.cancel();
            setState(() {
              _status = 'failed';
              _errorText = result['error']?.toString() ?? 'Đăng nhập thất bại.';
            });
          } else if (status == 'timeout') {
            timer.cancel();
            _timeoutTimer?.cancel();
            setState(() {
              _status = 'timeout';
            });
          }
        }
      } catch (e) {
        // Ignore polling errors transiently
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Liên Kết Tài Khoản Zalo',
      icon: Icons.qr_code_scanner_rounded,
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_status == 'loading') ...[
            const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              'Đang tạo phiên đăng nhập QR...',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ] else if (_status == 'pending' || _status == 'timeout') ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: AppSpacing.borderRadiusM,
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: AppSpacing.borderRadiusS,
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: _status == 'timeout' ? 4.5 : 0.0,
                          sigmaY: _status == 'timeout' ? 4.5 : 0.0,
                        ),
                        child: Image.network(
                          '${widget.baseUrl}$_qrUrl&t=${DateTime.now().millisecondsSinceEpoch}',
                          width: 180,
                          height: 180,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox(
                              width: 180,
                              height: 180,
                              child: Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 48,
                                  color: AppColors.error,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_status == 'timeout') ...[
                        Container(color: const Color(0x14000000)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textOnPrimary,
                            elevation: 4,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.m,
                              vertical: AppSpacing.s,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppSpacing.borderRadiusS,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _status = 'loading';
                              _errorText = null;
                            });
                            _startQrSession();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'Thử lại',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_status == 'pending') ...[
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    'Đang chờ quét mã QR...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.timer_off_outlined,
                    color: AppColors.error,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    'Mã QR đã hết hạn',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.errorText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              _status == 'pending'
                  ? 'Mở ứng dụng Zalo trên điện thoại di động và quét mã QR này để đăng nhập liên kết.'
                  : 'Nhấp vào nút "Thử lại" ở trên để tạo mã QR mới và tiếp tục đăng nhập.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(fontSize: 11.5),
            ),
          ] else if (_status == 'success') ...[
            const SizedBox(
              height: 180,
              child: Center(
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  size: 84,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              'Liên kết thành công!',
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.successText,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tài khoản mới đang được đồng bộ dữ liệu...',
              style: AppTextStyles.body.copyWith(fontSize: 12.5),
            ),
          ] else if (_status == 'failed') ...[
            SizedBox(
              height: 180,
              child: Center(
                child: Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 64,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              'Liên kết thất bại',
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.errorText,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Text(
                _errorText ?? 'Đã xảy ra lỗi không xác định.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: AppSpacing.borderRadiusS,
                ),
              ),
              onPressed: () {
                setState(() {
                  _status = 'loading';
                  _errorText = null;
                });
                _startQrSession();
              },
              child: const Text('Thử lại'),
            ),
          ],
          const SizedBox(height: AppSpacing.m),
        ],
      ),
    );
  }
}
