import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../mock/mock_campaigns.dart';
import '../../../../shared/utils/zalo_compliance_guard.dart';
import '../../../../shared/utils/zalo_text_formatter.dart';
import '../../../../shared/widgets/activity_log_panel.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../../zalo_integration/data/zalo_integration_api.dart';
import '../../../groups/manage/providers/managed_groups_provider.dart';
import '../data/bulk_campaign_repository.dart';
import '../data/scheduled_campaign.dart';

const Object _unsetSelectedAccount = Object();
const Object _unsetSelectedGroup = Object();
const Object _unsetScheduledAt = Object();

/// Send-target modes for the "Gửi vào nhóm Zalo" tab.
enum GroupSendMode {
  /// Send a single message into the group thread.
  toGroup,

  /// Send a personalized message to each member of the group.
  toMembers,
}

/// Per-recipient metadata used for personalization (name/avatar) and for
/// deciding the Zalo thread type when building the campaign payload.
class BulkRecipient {
  final String id; // phone, userId or groupId
  final String name;
  final String avatarUrl;
  final String threadType; // 'user' | 'group'

  const BulkRecipient({
    required this.id,
    this.name = '',
    this.avatarUrl = '',
    this.threadType = 'user',
  });
}

List<ZaloAccount> _mapBulkAccounts(List<ZaloConnectedAccount> accounts) {
  final seenIds = <String>{};
  return accounts
      .map(
        (acc) => ZaloAccount(
          id: acc.id,
          name: acc.label,
          phone: acc.id,
          type: 'Cá nhân',
          isConnected: acc.connected,
        ),
      )
      .where((acc) => seenIds.add(acc.id))
      .toList();
}

@visibleForTesting
List<ZaloAccount> mapBulkAccountsForTest(List<ZaloConnectedAccount> accounts) =>
    _mapBulkAccounts(accounts);

ZaloAccount? _resolveBulkSelectedAccount(
  ZaloAccount? current,
  List<ZaloAccount> accounts,
) {
  if (accounts.isEmpty) return null;

  if (current != null) {
    for (final account in accounts) {
      if (account.id == current.id) return account;
    }
  }

  return accounts.firstWhere(
    (a) => a.isConnected,
    orElse: () => accounts.first,
  );
}

String _bulkAccountFilterId(ZaloAccount? account) {
  if (account == null) return '';
  return account.id;
}

String bulkAccountFilterId(ZaloAccount? account) =>
    _bulkAccountFilterId(account);

@visibleForTesting
ZaloAccount? resolveBulkSelectedAccountForTest(
  ZaloAccount? current,
  List<ZaloAccount> accounts,
) => _resolveBulkSelectedAccount(current, accounts);

@visibleForTesting
String bulkAccountFilterIdForTest(ZaloAccount? account) =>
    bulkAccountFilterId(account);

class BulkMessagingState {
  final int
  selectedTab; // 0: Theo SĐT, 1: Vào nhóm, 2: Cho bạn bè, 3: Theo nhãn
  final String campaignName;
  final String recipientsText;
  final int minDelay;
  final int maxDelay;
  final String messageText;
  final ZaloAccount? selectedAccount;
  final List<ZaloAccount> accounts;
  final bool isSending;
  final List<LogItem> logs;
  final int successCount;
  final int failureCount;
  final int cancelledCount;
  final int totalCount;
  final String? complianceError;
  final String? complianceWarning;
  final String? activeCampaignId;
  final bool isPolling;
  // Tab 1 ("Gửi vào nhóm Zalo") state.
  final GroupSendMode groupSendMode;
  final ManagedZaloGroup? selectedGroup;
  // Per-recipient metadata keyed by recipient id (phone/userId/groupId).
  final Map<String, BulkRecipient> recipientInfo;
  // Compose-time picked send time. Null = send immediately. The actual queue of
  // armed campaigns lives in [scheduledCampaignsProvider]; this is only the value
  // currently selected in the date/time picker.
  final DateTime? scheduledAt;

  const BulkMessagingState({
    required this.selectedTab,
    required this.campaignName,
    required this.recipientsText,
    required this.minDelay,
    required this.maxDelay,
    required this.messageText,
    this.selectedAccount,
    required this.accounts,
    required this.isSending,
    required this.logs,
    required this.successCount,
    required this.failureCount,
    required this.cancelledCount,
    required this.totalCount,
    this.complianceError,
    this.complianceWarning,
    this.activeCampaignId,
    this.isPolling = false,
    this.groupSendMode = GroupSendMode.toGroup,
    this.selectedGroup,
    this.recipientInfo = const {},
    this.scheduledAt,
  });

  factory BulkMessagingState.initial() {
    return const BulkMessagingState(
      selectedTab: 0,
      campaignName: '',
      recipientsText: '',
      minDelay: 30,
      maxDelay: 60,
      messageText: '',
      selectedAccount: null,
      accounts: [],
      isSending: false,
      logs: [],
      successCount: 0,
      failureCount: 0,
      cancelledCount: 0,
      totalCount: 0,
    );
  }

  /// Recipient ids currently queued (one per non-empty line).
  List<String> get recipientIds => recipientsText
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// Whether the campaign has a valid target for the current tab/mode.
  bool get hasValidRecipients => recipientIds.isNotEmpty;

  BulkMessagingState copyWith({
    int? selectedTab,
    String? campaignName,
    String? recipientsText,
    int? minDelay,
    int? maxDelay,
    String? messageText,
    Object? selectedAccount = _unsetSelectedAccount,
    List<ZaloAccount>? accounts,
    bool? isSending,
    List<LogItem>? logs,
    int? successCount,
    int? failureCount,
    int? cancelledCount,
    int? totalCount,
    String? complianceError,
    String? complianceWarning,
    bool clearComplianceError = false,
    bool clearComplianceWarning = false,
    String? activeCampaignId,
    bool? isPolling,
    GroupSendMode? groupSendMode,
    Object? selectedGroup = _unsetSelectedGroup,
    Map<String, BulkRecipient>? recipientInfo,
    Object? scheduledAt = _unsetScheduledAt,
  }) {
    return BulkMessagingState(
      selectedTab: selectedTab ?? this.selectedTab,
      campaignName: campaignName ?? this.campaignName,
      recipientsText: recipientsText ?? this.recipientsText,
      minDelay: minDelay ?? this.minDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      messageText: messageText ?? this.messageText,
      selectedAccount: identical(selectedAccount, _unsetSelectedAccount)
          ? this.selectedAccount
          : selectedAccount as ZaloAccount?,
      accounts: accounts ?? this.accounts,
      isSending: isSending ?? this.isSending,
      logs: logs ?? this.logs,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      cancelledCount: cancelledCount ?? this.cancelledCount,
      totalCount: totalCount ?? this.totalCount,
      complianceError: clearComplianceError
          ? null
          : (complianceError ?? this.complianceError),
      complianceWarning: clearComplianceWarning
          ? null
          : (complianceWarning ?? this.complianceWarning),
      activeCampaignId: activeCampaignId ?? this.activeCampaignId,
      isPolling: isPolling ?? this.isPolling,
      groupSendMode: groupSendMode ?? this.groupSendMode,
      selectedGroup: identical(selectedGroup, _unsetSelectedGroup)
          ? this.selectedGroup
          : selectedGroup as ManagedZaloGroup?,
      recipientInfo: recipientInfo ?? this.recipientInfo,
      scheduledAt: identical(scheduledAt, _unsetScheduledAt)
          ? this.scheduledAt
          : scheduledAt as DateTime?,
    );
  }
}

class BulkMessagingNotifier extends StateNotifier<BulkMessagingState> {
  final Ref _ref;
  final BulkCampaignRepository _repository;
  Timer? _pollingTimer;

  BulkMessagingNotifier(this._ref, this._repository)
    : super(BulkMessagingState.initial()) {
    // Listen to changes in zaloIntegrationProvider to update our accounts list
    _ref.listen<ZaloIntegrationState>(zaloIntegrationProvider, (
      previous,
      next,
    ) {
      final seenIds = <String>{};
      final newAccounts = next.accounts
          .map(
            (acc) => ZaloAccount(
              id: acc.id,
              name: acc.label,
              phone: acc.id,
              type: 'Cá nhân',
              isConnected: acc.connected,
            ),
          )
          .where((acc) => seenIds.add(acc.id))
          .toList();

      state = state.copyWith(
        accounts: newAccounts,
        selectedAccount: _resolveBulkSelectedAccount(
          state.selectedAccount,
          newAccounts,
        ),
      );
    });

    // Initialize list immediately if accounts are already populated
    final integrationState = _ref.read(zaloIntegrationProvider);
    if (integrationState.accounts.isNotEmpty) {
      final seenIds = <String>{};
      final initialAccounts = integrationState.accounts
          .map(
            (acc) => ZaloAccount(
              id: acc.id,
              name: acc.label,
              phone: acc.id,
              type: 'Cá nhân',
              isConnected: acc.connected,
            ),
          )
          .where((acc) => seenIds.add(acc.id))
          .toList();

      state = state.copyWith(
        accounts: initialAccounts,
        selectedAccount: _resolveBulkSelectedAccount(null, initialAccounts),
      );
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void setSelectedTab(int index) {
    state = state.copyWith(
      selectedTab: index,
      clearComplianceError: true,
      clearComplianceWarning: true,
    );
    _checkCompliance();
  }

  void setCampaignName(String name) {
    state = state.copyWith(campaignName: name);
  }

  void setRecipientsText(String text) {
    state = state.copyWith(recipientsText: text);
    _checkCompliance();
  }

  void setMinDelay(int min) {
    state = state.copyWith(minDelay: min);
  }

  void setMaxDelay(int max) {
    state = state.copyWith(maxDelay: max);
  }

  void setMessageText(String text) {
    state = state.copyWith(messageText: text);
    _checkCompliance();
  }

  void selectAccount(ZaloAccount? account) {
    state = state.copyWith(selectedAccount: account);
    _checkCompliance();
  }

  /// Switch the "Gửi vào nhóm Zalo" sub-mode (to-group vs to-members) and reset
  /// any queued recipients since the target shape changes between modes.
  void setGroupSendMode(GroupSendMode mode) {
    if (state.groupSendMode == mode) return;
    state = state.copyWith(
      groupSendMode: mode,
      selectedGroup: null,
      recipientsText: '',
      recipientInfo: const {},
      clearComplianceError: true,
      clearComplianceWarning: true,
    );
  }

  /// Select a group in tab 1. In to-group mode the group thread becomes the
  /// single recipient; in to-members mode recipients are added separately once
  /// members are scanned and picked.
  void selectGroup(ManagedZaloGroup? group) {
    if (group == null) {
      state = state.copyWith(
        selectedGroup: null,
        recipientsText: '',
        recipientInfo: const {},
      );
      _checkCompliance();
      return;
    }

    if (state.groupSendMode == GroupSendMode.toGroup) {
      state = state.copyWith(
        selectedGroup: group,
        recipientsText: group.groupId,
        recipientInfo: {
          group.groupId: BulkRecipient(
            id: group.groupId,
            name: group.name,
            avatarUrl: group.avatarUrl,
            threadType: 'group',
          ),
        },
      );
    } else {
      // Members mode: clear previous member selection; members are filled in by
      // the screen once the group is scanned.
      state = state.copyWith(
        selectedGroup: group,
        recipientsText: '',
        recipientInfo: const {},
      );
    }
    _checkCompliance();
  }

  /// Replace recipient metadata (name/avatar/threadType) for personalization.
  /// The recipient id list itself is owned by the text controller in the UI; this
  /// only stores the lookup table keyed by id.
  void replaceRecipientInfo(List<BulkRecipient> recipients) {
    final info = <String, BulkRecipient>{};
    for (final r in recipients) {
      if (r.id.isNotEmpty) info[r.id] = r;
    }
    state = state.copyWith(recipientInfo: info);
  }

  /// Merge/replace metadata for already-queued recipients (e.g. once an avatar
  /// or nickname is resolved for a manually-added phone number).
  void upsertRecipientInfo(BulkRecipient recipient) {
    if (recipient.id.isEmpty) return;
    state = state.copyWith(
      recipientInfo: {...state.recipientInfo, recipient.id: recipient},
    );
  }

  /// Store the picked send time (or clear it with null). The queue itself is
  /// owned by [scheduledCampaignsProvider]; pressing "Hẹn giờ gửi" in the UI
  /// takes a snapshot via [buildScheduledSnapshot] and arms it there.
  void setScheduledAt(DateTime? dt) {
    state = state.copyWith(scheduledAt: dt);
  }

  /// Capture an immutable snapshot of the current compose form for scheduling.
  /// Returns null (and surfaces a compliance error) if the form is not in a
  /// valid sendable state. Mirrors the payload shaping in [startSending] so a
  /// scheduled send behaves identically to an immediate one.
  ScheduledCampaign? buildScheduledSnapshot() {
    final at = state.scheduledAt;
    if (at == null) return null;
    final recipients = state.recipientIds;
    if (recipients.isEmpty || state.messageText.trim().isEmpty) return null;

    final settings = _ref.read(settingsProvider).settings;
    final decision = ZaloComplianceGuard.evaluateZaloAction(
      settings: settings,
      actionType: _actionTypeForTab(),
      targetCount: recipients.length,
    );
    if (!decision.allowed) {
      state = state.copyWith(
        complianceError: '${decision.title}: ${decision.message}',
      );
      return null;
    }

    final isGroupMessage =
        state.selectedTab == 1 && state.groupSendMode == GroupSendMode.toGroup;
    final now = DateTime.now();
    return ScheduledCampaign(
      id: now.microsecondsSinceEpoch.toString(),
      name: state.campaignName.trim(),
      message: state.messageText.trim(),
      isGroupMessage: isGroupMessage,
      recipients: recipients
          .map(
            (r) => ScheduledRecipient(
              id: r,
              name: state.recipientInfo[r]?.name ?? '',
            ),
          )
          .toList(),
      accountId: state.selectedAccount?.id,
      minDelay: state.minDelay,
      maxDelay: state.maxDelay,
      requireHumanApproval: decision.requiredActions.contains('human_approval'),
      scheduledAt: at,
      status: ScheduledStatus.pending,
      createdAt: now,
    );
  }

  void _checkCompliance() {
    final recipients = state.recipientsText
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (recipients.isEmpty) {
      state = state.copyWith(
        clearComplianceError: true,
        clearComplianceWarning: true,
      );
      return;
    }

    final settings = _ref.read(settingsProvider).settings;
    final decision = ZaloComplianceGuard.evaluateZaloAction(
      settings: settings,
      actionType: _actionTypeForTab(),
      targetCount: recipients.length,
    );

    if (!decision.allowed) {
      state = state.copyWith(
        complianceError: '${decision.title}: ${decision.message}',
        clearComplianceWarning: true,
      );
    } else if (decision.riskLevel == ZaloRiskLevel.medium ||
        decision.riskLevel == ZaloRiskLevel.high) {
      state = state.copyWith(
        clearComplianceError: true,
        complianceWarning: '${decision.title}: ${decision.message}',
      );
    } else {
      state = state.copyWith(
        clearComplianceError: true,
        clearComplianceWarning: true,
      );
    }
  }

  void clearLogs() {
    state = state.copyWith(
      logs: [],
      successCount: 0,
      failureCount: 0,
      cancelledCount: 0,
      totalCount: 0,
    );
  }

  void addLog(String message, {LogType type = LogType.info}) {
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
    state = state.copyWith(
      logs: [
        ...state.logs,
        LogItem(timestamp: timeStr, message: message, type: type),
      ],
    );
  }

  ZaloActionType _actionTypeForTab() {
    switch (state.selectedTab) {
      case 0:
        return ZaloActionType.bulkMessageByPhone;
      case 1:
        // Sending into the group thread vs to individual members are different
        // risk profiles.
        return state.groupSendMode == GroupSendMode.toGroup
            ? ZaloActionType.bulkMessageToGroup
            : ZaloActionType.bulkMessageToFriends;
      case 2:
        return ZaloActionType.bulkMessageToFriends;
      default:
        return ZaloActionType.bulkMessageByPhone;
    }
  }

  Future<void> startSending() async {
    if (state.isSending) return;

    final recipients = state.recipientsText
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (recipients.isEmpty) return;
    if (state.messageText.trim().isEmpty) {
      state = state.copyWith(
        complianceError: 'Vui lòng nhập nội dung tin nhắn.',
      );
      return;
    }

    // Compliance check
    final settings = _ref.read(settingsProvider).settings;
    final decision = ZaloComplianceGuard.evaluateZaloAction(
      settings: settings,
      actionType: _actionTypeForTab(),
      targetCount: recipients.length,
    );

    if (!decision.allowed) {
      state = state.copyWith(
        complianceError: '${decision.title}: ${decision.message}',
      );
      return;
    }

    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
    state = state.copyWith(
      isSending: true,
      successCount: 0,
      failureCount: 0,
      cancelledCount: 0,
      totalCount: recipients.length,
      clearComplianceError: true,
      logs: [
        LogItem(
          timestamp: timeStr,
          message: '[Hệ thống] Đang khởi tạo chiến dịch trên Cloud...',
          type: LogType.info,
        ),
        LogItem(
          timestamp: timeStr,
          message:
              '[Hệ thống] Thiết bị gửi: Windows/Zalo agent đang hoạt động trên Cloud',
          type: LogType.info,
        ),
      ],
    );

    try {
      final campaignId = await launchCampaign(
        _repository,
        CampaignLaunchParams(
          name: state.campaignName,
          message: state.messageText,
          isGroupMessage: state.selectedTab == 1 &&
              state.groupSendMode == GroupSendMode.toGroup,
          recipientIds: recipients,
          recipientNames: {
            for (final r in recipients) r: state.recipientInfo[r]?.name ?? '',
          },
          accountId: state.selectedAccount?.id,
          minDelay: state.minDelay,
          maxDelay: state.maxDelay,
          requireHumanApproval:
              decision.requiredActions.contains('human_approval'),
        ),
      );

      final nowTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
      state = state.copyWith(
        activeCampaignId: campaignId,
        logs: [
          ...state.logs,
          LogItem(
            timestamp: nowTimeStr,
            message:
                '[Hệ thống] Đã đưa lệnh vào hàng đợi Cloud. Bắt đầu xử lý...',
            type: LogType.info,
          ),
        ],
      );

      // 3. Poll for progress
      _startPolling(campaignId);
    } catch (e) {
      final nowTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
      state = state.copyWith(
        isSending: false,
        complianceError: 'Lỗi: ${e.toString()}',
        logs: [
          ...state.logs,
          LogItem(
            timestamp: nowTimeStr,
            message: 'Lỗi: ${e.toString()}',
            type: LogType.error,
          ),
        ],
      );
    }
  }

  void _startPolling(String campaignId) {
    _pollingTimer?.cancel();
    state = state.copyWith(isPolling: true);

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final resp = await _repository.getCampaignStatus(campaignId);
        if (resp['success']) {
          final data = resp['data'];
          final statusCounts = data['statusCounts'] ?? {};
          final campaignStatus = data['campaign']['status'];
          final commandStatus = data['commandStatus']?.toString();
          final commandError = data['commandError']?.toString();

          final success = statusCounts['success'] ?? 0;
          final failed = statusCounts['failed'] ?? 0;
          final cancelled = statusCounts['cancelled'] ?? 0;

          String? displayError;
          if (commandStatus == 'failed' &&
              commandError != null &&
              commandError.isNotEmpty) {
            displayError = ZaloIntegrationApi.translateToVietnamese(
              commandError,
            );
          }

          state = state.copyWith(
            successCount: success,
            failureCount: failed,
            cancelledCount: cancelled,
            complianceError: displayError,
          );

          // If campaign is done or cancelled or command failed
          if (campaignStatus == 'completed' ||
              campaignStatus == 'cancelled' ||
              commandStatus == 'failed') {
            timer.cancel();

            final nowTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
            final displayErrorText = displayError ?? 'Lỗi không rõ';
            String statusText = campaignStatus;
            if (campaignStatus == 'completed') statusText = 'hoàn thành';
            if (campaignStatus == 'cancelled') statusText = 'bị hủy';

            state = state.copyWith(
              isSending: false,
              isPolling: false,
              activeCampaignId: null,
              complianceError: displayError,
              logs: [
                ...state.logs,
                if (commandStatus == 'failed' && displayError != null)
                  LogItem(
                    timestamp: nowTimeStr,
                    message:
                        '[Hệ thống] Chiến dịch thất bại: $displayErrorText. Thành công: $success, Thất bại: $failed, Đã hủy: $cancelled',
                    type: LogType.error,
                  )
                else
                  LogItem(
                    timestamp: nowTimeStr,
                    message:
                        '[Hệ thống] Chiến dịch $statusText. Thành công: $success, Thất bại: $failed, Đã hủy: $cancelled',
                    type: campaignStatus == 'completed'
                        ? LogType.success
                        : LogType.warning,
                  ),
              ],
            );
          }
        }
      } catch (e) {
        debugPrint('Lỗi poll trạng thái: $e');
      }
    });
  }

  Future<void> stopSending() async {
    if (!state.isSending || state.activeCampaignId == null) return;

    final campaignId = state.activeCampaignId!;
    try {
      final nowTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
      state = state.copyWith(
        logs: [
          ...state.logs,
          LogItem(
            timestamp: nowTimeStr,
            message: '[Hệ thống] Đang gửi yêu cầu hủy...',
            type: LogType.info,
          ),
        ],
      );
      await _repository.cancelCampaign(campaignId);
      // Polling will catch the 'cancelled' state and clean up
    } catch (e) {
      final nowTimeStr = DateFormat('HH:mm:ss').format(DateTime.now());
      state = state.copyWith(
        complianceError: 'Không thể hủy chiến dịch: ${e.toString()}',
        logs: [
          ...state.logs,
          LogItem(
            timestamp: nowTimeStr,
            message: 'Không thể hủy chiến dịch: ${e.toString()}',
            type: LogType.error,
          ),
        ],
      );
    }
  }
}

/// Everything needed to launch a campaign, independent of any UI state, so both
/// the immediate send ([BulkMessagingNotifier.startSending]) and the scheduled
/// send ([scheduledCampaignsProvider]) share one code path.
class CampaignLaunchParams {
  final String name;
  final String message; // raw markdown; formatting applied in launchCampaign
  final bool isGroupMessage;
  final List<String> recipientIds;
  final Map<String, String> recipientNames; // id -> display name
  final String? accountId;
  final int minDelay;
  final int maxDelay;
  final bool requireHumanApproval;

  const CampaignLaunchParams({
    required this.name,
    required this.message,
    required this.isGroupMessage,
    required this.recipientIds,
    required this.recipientNames,
    required this.accountId,
    required this.minDelay,
    required this.maxDelay,
    required this.requireHumanApproval,
  });
}

/// Create template + create campaign + start it. Returns the campaignId on
/// success; throws on any failure. Sending into a group thread uses
/// targetGroupIds; everything else uses manualRecipients with display names for
/// personalization.
Future<String> launchCampaign(
  BulkCampaignRepository repository,
  CampaignLaunchParams p,
) async {
  final finalMessage = ZaloTextFormatter.formatMarkdownToUnicode(
    p.message.trim(),
  );
  final name = p.name.trim();

  final templateResp = await repository.createTemplate({
    'name': name.isNotEmpty
        ? '$name - Nội dung gửi'
        : 'Bulk template ${DateTime.now().toIso8601String()}',
    'body': finalMessage,
    'type': 'zalo',
    'category': 'bulk',
    'isQuick': false,
    'status': 'active',
    'language': 'vi',
  });
  if (templateResp['success'] != true || templateResp['data'] == null) {
    throw Exception(templateResp['message'] ?? 'Tạo mẫu tin nhắn thất bại');
  }
  final templateId =
      templateResp['data']['_id']?.toString() ??
      templateResp['data']['id']?.toString();
  if (templateId == null || templateId.isEmpty) {
    throw Exception('Máy chủ không trả về templateId hợp lệ.');
  }

  final targetGroupIds = p.isGroupMessage ? p.recipientIds : const <String>[];
  final manualRecipients = p.isGroupMessage
      ? const <Map<String, String>>[]
      : p.recipientIds
            .map((r) => {'phone': r, 'name': p.recipientNames[r] ?? ''})
            .toList();

  final createResp = await repository.createCampaign({
    'name': name.isNotEmpty
        ? name
        : 'Bulk Campaign ${DateTime.now().toIso8601String()}',
    'templateId': templateId,
    'channel': 'zalo',
    'audienceType': p.isGroupMessage ? 'group' : 'manual',
    'manualRecipients': manualRecipients,
    if (targetGroupIds.isNotEmpty) 'targetGroupIds': targetGroupIds,
    if (p.accountId != null && p.accountId!.isNotEmpty)
      'selectedAccountId': p.accountId,
    'rateLimit': {
      'minDelaySeconds': p.minDelay,
      'maxDelaySeconds': p.maxDelay,
    },
    'requireHumanApproval': p.requireHumanApproval,
  });
  if (createResp['success'] != true) {
    throw Exception(createResp['message'] ?? 'Tạo chiến dịch thất bại');
  }
  final campaignId = createResp['data']['_id'].toString();

  final humanApprovedAt = p.requireHumanApproval
      ? DateTime.now().toIso8601String()
      : null;
  final startResp = await repository.startCampaign(
    campaignId,
    humanApprovedAt: humanApprovedAt,
  );
  if (startResp['success'] != true) {
    throw Exception(startResp['message'] ?? 'Bắt đầu chiến dịch thất bại');
  }
  return campaignId;
}

final bulkMessagingProvider =
    StateNotifierProvider<BulkMessagingNotifier, BulkMessagingState>((ref) {
      final repository = BulkCampaignRepository();
      return BulkMessagingNotifier(ref, repository);
    });
