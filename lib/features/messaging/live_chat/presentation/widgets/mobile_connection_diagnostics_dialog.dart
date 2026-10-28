import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/api/crm_sse_client.dart';
import '../../../../../shared/api/crm_sse_provider.dart';
import '../../../../../shared/utils/app_update_service.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../devices/providers/crm_device_provider.dart';
import '../../providers/agent_status_provider.dart';
import '../../providers/live_chat_provider.dart';
import '../../utils/mobile_connection_diagnostics.dart';

Future<void> showMobileConnectionDiagnosticsDialog(BuildContext context) {
  return showStandardDialog<void>(
    context: context,
    builder: (dialogContext) => const MobileConnectionDiagnosticsDialog(),
  );
}

class MobileConnectionDiagnosticsDialog extends ConsumerStatefulWidget {
  final String? mobileAppVersionOverride;

  const MobileConnectionDiagnosticsDialog({
    super.key,
    this.mobileAppVersionOverride,
  });

  @override
  ConsumerState<MobileConnectionDiagnosticsDialog> createState() =>
      _MobileConnectionDiagnosticsDialogState();
}

class _MobileConnectionDiagnosticsDialogState
    extends ConsumerState<MobileConnectionDiagnosticsDialog> {
  bool _reconnecting = false;
  bool _copied = false;
  String? _mobileAppVersion;

  @override
  void initState() {
    super.initState();
    _mobileAppVersion = widget.mobileAppVersionOverride;
    if (_mobileAppVersion == null) {
      _loadMobileAppVersion();
    }
  }

  Future<void> _loadMobileAppVersion() async {
    final version = await AppUpdateService.getCurrentVersion();
    if (!mounted) return;
    if (version.isNotEmpty && version != '0.0.0') {
      setState(() {
        _mobileAppVersion = version;
      });
    }
  }

  Future<void> _handleCopyReport(
    MobileConnectionSnapshot snapshot,
    List<CrmConnectionLogEntry> logs,
  ) async {
    final report = buildRedactedDiagnosticsReport(
      snapshot,
      logs,
      mobileAppVersion: _mobileAppVersion,
    );
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    setState(() {
      _copied = true;
    });
  }

  Future<void> _handleReconnectNow(CrmSseClient sseClient) async {
    setState(() {
      _reconnecting = true;
      _copied = false;
    });
    sseClient.reconnectNow(reason: 'diagnostics_dialog');
    await ref.read(crmDeviceProvider.notifier).checkPairingStatus();
    if (!mounted) return;
    setState(() {
      _reconnecting = false;
    });
  }

  Color _severityColor(MobileConnectionIssueSeverity severity) {
    switch (severity) {
      case MobileConnectionIssueSeverity.healthy:
        return AppColors.success;
      case MobileConnectionIssueSeverity.info:
        return AppColors.info;
      case MobileConnectionIssueSeverity.warning:
        return AppColors.warning;
      case MobileConnectionIssueSeverity.error:
        return AppColors.error;
    }
  }

  Color _severitySoftColor(MobileConnectionIssueSeverity severity) {
    switch (severity) {
      case MobileConnectionIssueSeverity.healthy:
        return AppColors.successSoft;
      case MobileConnectionIssueSeverity.info:
        return AppColors.infoSoft;
      case MobileConnectionIssueSeverity.warning:
        return AppColors.warningSoft;
      case MobileConnectionIssueSeverity.error:
        return AppColors.errorSoft;
    }
  }

  Color _severityTextColor(MobileConnectionIssueSeverity severity) {
    switch (severity) {
      case MobileConnectionIssueSeverity.healthy:
        return AppColors.successText;
      case MobileConnectionIssueSeverity.info:
        return AppColors.info;
      case MobileConnectionIssueSeverity.warning:
        return AppColors.warningText;
      case MobileConnectionIssueSeverity.error:
        return AppColors.errorText;
    }
  }

  IconData _severityIcon(MobileConnectionIssueSeverity severity) {
    switch (severity) {
      case MobileConnectionIssueSeverity.healthy:
        return Icons.check_circle_rounded;
      case MobileConnectionIssueSeverity.info:
        return Icons.info_outline_rounded;
      case MobileConnectionIssueSeverity.warning:
        return Icons.warning_amber_rounded;
      case MobileConnectionIssueSeverity.error:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final transportMode = ref.watch(liveChatTransportModeProvider);
    final deviceState = ref.watch(crmDeviceProvider);
    final agentStatus = ref.watch(agentStatusProvider);
    final sseClient = ref.watch(crmSseClientProvider);

    return ValueListenableBuilder<SseConnectionState>(
      valueListenable: sseClient.connectionState,
      builder: (context, sseState, _) {
        return ValueListenableBuilder<List<CrmConnectionLogEntry>>(
          valueListenable: sseClient.connectionLog,
          builder: (context, logs, _) {
            final matchedDevice = deviceState.deviceId != null
                ? agentStatus.devicesById[deviceState.deviceId!]
                : null;
            final anyDeviceOnline = matchedDevice != null
                ? matchedDevice.online
                : agentStatus.anyDeviceOnline;
            final hasZaloIssue = matchedDevice != null
                ? (matchedDevice.online &&
                      (matchedDevice.worstZaloHealth ==
                              ZaloAccountHealth.expired ||
                          matchedDevice.worstZaloHealth ==
                              ZaloAccountHealth.loggedOut))
                : agentStatus.anyOnlineDeviceHasZaloIssue;

            final effectiveIsPaired = deviceState.hasLoaded
                ? deviceState.isPaired
                : true;

            final snapshot = MobileConnectionSnapshot(
              transportMode: transportMode,
              isPaired: effectiveIsPaired,
              sseState: sseState,
              showReconnectBanner: agentStatus.showReconnectBanner,
              reconnectAttempts: sseClient.reconnectAttempts,
              lastHttpStatus: sseClient.lastHttpStatus,
              lastError: sseClient.lastError,
              hasAgentSnapshot: agentStatus.hasSnapshot,
              anyDeviceOnline: anyDeviceOnline,
              anyOnlineDeviceHasZaloIssue: hasZaloIssue,
              lastHeartbeatAt:
                  matchedDevice?.lastHeartbeatAt ??
                  agentStatus.latestHeartbeatAt,
              mobileAppVersion: _mobileAppVersion,
              desktopAppVersion:
                  matchedDevice?.appVersion ??
                  agentStatus.primaryDesktopAppVersion,
              desktopAgentVersion:
                  matchedDevice?.agentVersion ??
                  agentStatus.primaryDesktopAgentVersion,
            );

            final diagnosis = diagnoseMobileConnection(snapshot);
            final recentLogs = logs.reversed.take(30).toList();
            final canReconnect =
                !_reconnecting && sseState != SseConnectionState.connecting;

            return AppDialog(
              title: 'Chẩn Đoán Kết Nối',
              subtitle:
                  'Kiểm tra trạng thái đồng bộ giữa Điện thoại, Đám mây và Máy tính chủ',
              icon: Icons.troubleshoot_rounded,
              width: 580,
              actions: [
                AppDialogAction(
                  text: _copied ? 'Đã sao chép' : 'Sao chép báo cáo',
                  icon: _copied
                      ? Icons.check_rounded
                      : Icons.copy_all_rounded,
                  variant: AppButtonVariant.outline,
                  onPressed: () => _handleCopyReport(snapshot, logs),
                ),
                AppDialogAction(
                  text: 'Kết nối lại ngay',
                  icon: Icons.refresh_rounded,
                  variant: AppButtonVariant.outline,
                  onPressed: canReconnect
                      ? () => _handleReconnectNow(sseClient)
                      : null,
                ),
                AppDialogAction(
                  text: 'Đóng',
                  variant: AppButtonVariant.primary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: _severitySoftColor(diagnosis.severity),
                      borderRadius: AppSpacing.borderRadiusM,
                      border: Border.all(
                        color: _severityColor(
                          diagnosis.severity,
                        ).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _severityIcon(diagnosis.severity),
                              color: _severityTextColor(diagnosis.severity),
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.s),
                            Expanded(
                              child: Text(
                                diagnosis.title,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _severityTextColor(diagnosis.severity),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          diagnosis.likelyCause,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Hướng xử lý: ${diagnosis.nextStep}',
                          style: AppTextStyles.caption.copyWith(
                            color: _severityTextColor(diagnosis.severity),
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_copied) ...[
                    const SizedBox(height: AppSpacing.s),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: AppColors.successText,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'Đã sao chép báo cáo chẩn đoán (đã ẩn thông tin nhạy cảm) vào bộ nhớ tạm.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.successText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    'DANH SÁCH KIỂM TRA',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: AppSpacing.borderRadiusM,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        for (
                          var i = 0;
                          i < diagnosis.checks.length;
                          i++
                        ) ...[
                          if (i > 0) const Divider(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  _severityIcon(diagnosis.checks[i].severity),
                                  size: 16,
                                  color: _severityColor(
                                    diagnosis.checks[i].severity,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      diagnosis.checks[i].label,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      diagnosis.checks[i].statusText,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    'NHẬT KÝ KẾT NỐI GẦN ĐÂY (${recentLogs.length})',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: AppSpacing.borderRadiusM,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: recentLogs.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(AppSpacing.s),
                              child: Text(
                                'Chưa có sự kiện kết nối nào được ghi nhận.',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: recentLogs.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final entry = recentLogs[index];
                                final timeStr = DateFormat(
                                  'HH:mm:ss',
                                ).format(entry.timestamp.toLocal());
                                final detail =
                                    entry.detail == null ||
                                        entry.detail!.isEmpty
                                    ? ''
                                    : ' — ${redactConnectionLogText(entry.detail!)}';
                                return Text(
                                  '$timeStr [${entry.level.name.toUpperCase()}] ${entry.code}$detail',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11.5,
                                    color: Color(0xFFE2E8F0),
                                    height: 1.35,
                                  ),
                                );
                              },
                            ),
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
}
