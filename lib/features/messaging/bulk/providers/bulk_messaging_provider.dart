import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../mock/mock_campaigns.dart';
import '../../../../shared/utils/zalo_compliance_guard.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../data/bulk_campaign_repository.dart';

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
  final List<String> logs;
  final int successCount;
  final int failureCount;
  final int cancelledCount;
  final int totalCount;
  final String? complianceError;
  final String? activeCampaignId;
  final bool isPolling;

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
    this.activeCampaignId,
    this.isPolling = false,
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

  BulkMessagingState copyWith({
    int? selectedTab,
    String? campaignName,
    String? recipientsText,
    int? minDelay,
    int? maxDelay,
    String? messageText,
    ZaloAccount? selectedAccount,
    List<ZaloAccount>? accounts,
    bool? isSending,
    List<String>? logs,
    int? successCount,
    int? failureCount,
    int? cancelledCount,
    int? totalCount,
    String? complianceError,
    String? activeCampaignId,
    bool? isPolling,
  }) {
    return BulkMessagingState(
      selectedTab: selectedTab ?? this.selectedTab,
      campaignName: campaignName ?? this.campaignName,
      recipientsText: recipientsText ?? this.recipientsText,
      minDelay: minDelay ?? this.minDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      messageText: messageText ?? this.messageText,
      selectedAccount: selectedAccount ?? this.selectedAccount,
      accounts: accounts ?? this.accounts,
      isSending: isSending ?? this.isSending,
      logs: logs ?? this.logs,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      cancelledCount: cancelledCount ?? this.cancelledCount,
      totalCount: totalCount ?? this.totalCount,
      complianceError: complianceError, // explicitly clear if not provided
      activeCampaignId: activeCampaignId ?? this.activeCampaignId,
      isPolling: isPolling ?? this.isPolling,
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
    _ref.listen<ZaloIntegrationState>(zaloIntegrationProvider, (previous, next) {
      final seenIds = <String>{};
      final newAccounts = next.accounts
          .map((acc) => ZaloAccount(
                id: acc.id,
                name: acc.label,
                phone: acc.id,
                type: 'Cá nhân',
                isConnected: acc.connected,
              ))
          .where((acc) => seenIds.add(acc.id))
          .toList();

      state = state.copyWith(
        accounts: newAccounts,
        selectedAccount: state.selectedAccount == null && newAccounts.isNotEmpty
            ? newAccounts.firstWhere((a) => a.isConnected, orElse: () => newAccounts.first)
            : state.selectedAccount,
      );
    });

    // Initialize list immediately if accounts are already populated
    final integrationState = _ref.read(zaloIntegrationProvider);
    if (integrationState.accounts.isNotEmpty) {
      final seenIds = <String>{};
      final initialAccounts = integrationState.accounts
          .map((acc) => ZaloAccount(
                id: acc.id,
                name: acc.label,
                phone: acc.id,
                type: 'Cá nhân',
                isConnected: acc.connected,
              ))
          .where((acc) => seenIds.add(acc.id))
          .toList();

      state = state.copyWith(
        accounts: initialAccounts,
        selectedAccount: initialAccounts.firstWhere((a) => a.isConnected, orElse: () => initialAccounts.first),
      );
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void setSelectedTab(int index) {
    state = state.copyWith(selectedTab: index, complianceError: null);
  }

  void setCampaignName(String name) {
    state = state.copyWith(campaignName: name);
  }

  void setRecipientsText(String text) {
    state = state.copyWith(recipientsText: text);
  }

  void setMinDelay(int min) {
    state = state.copyWith(minDelay: min);
  }

  void setMaxDelay(int max) {
    state = state.copyWith(maxDelay: max);
  }

  void setMessageText(String text) {
    state = state.copyWith(messageText: text);
  }

  void selectAccount(ZaloAccount? account) {
    state = state.copyWith(selectedAccount: account);
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

  void addLog(String log) {
    state = state.copyWith(logs: [...state.logs, log]);
  }

  ZaloActionType _actionTypeForTab() {
    switch (state.selectedTab) {
      case 0:
        return ZaloActionType.bulkMessageByPhone;
      case 1:
        return ZaloActionType.bulkMessageToGroup;
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

    state = state.copyWith(
      isSending: true,
      successCount: 0,
      failureCount: 0,
      cancelledCount: 0,
      totalCount: recipients.length,
      complianceError: null,
      logs: [
        '[Hệ thống] Đang khởi tạo chiến dịch trên Cloud...',
        '[Hệ thống] Thiết bị gửi: Windows/Zalo agent đang hoạt động trên Cloud',
      ],
    );

    try {
      final templateResp = await _repository.createTemplate({
        'name': state.campaignName.trim().isNotEmpty
            ? '${state.campaignName.trim()} - Nội dung gửi'
            : 'Bulk template ${DateTime.now().toIso8601String()}',
        'body': state.messageText.trim(),
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

      // 1. Create campaign
      final createResp = await _repository.createCampaign({
        'name': state.campaignName.trim().isNotEmpty
            ? state.campaignName.trim()
            : 'Bulk Campaign ${DateTime.now().toIso8601String()}',
        'templateId': templateId,
        'channel': 'zalo',
        'audienceType': 'manual',
        'manualRecipients': recipients
            .map((r) => {'phone': r, 'name': ''})
            .toList(),
        if (state.selectedAccount != null)
          'selectedAccountId': state.selectedAccount!.id,
        'rateLimit': {
          'minDelaySeconds': state.minDelay,
          'maxDelaySeconds': state.maxDelay,
        },
        'requireHumanApproval': decision.requiredActions.contains(
          'human_approval',
        ),
      });

      if (!createResp['success']) {
        throw Exception(createResp['message'] ?? 'Tạo chiến dịch thất bại');
      }

      final campaignId = createResp['data']['_id'];

      // 2. Start campaign
      String? humanApprovedAt;
      if (decision.requiredActions.contains('human_approval')) {
        humanApprovedAt = DateTime.now().toIso8601String();
      }

      final startResp = await _repository.startCampaign(
        campaignId,
        humanApprovedAt: humanApprovedAt,
      );
      if (!startResp['success']) {
        throw Exception(startResp['message'] ?? 'Bắt đầu chiến dịch thất bại');
      }

      state = state.copyWith(
        activeCampaignId: campaignId,
        logs: [
          ...state.logs,
          '[Hệ thống] Đã đưa lệnh vào hàng đợi Cloud. Bắt đầu xử lý...',
        ],
      );

      // 3. Poll for progress
      _startPolling(campaignId);
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        complianceError: 'Lỗi: ${e.toString()}',
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

          final success = statusCounts['success'] ?? 0;
          final failed = statusCounts['failed'] ?? 0;
          final cancelled = statusCounts['cancelled'] ?? 0;

          state = state.copyWith(
            successCount: success,
            failureCount: failed,
            cancelledCount: cancelled,
          );

          // If campaign is done or cancelled
          if (campaignStatus == 'completed' || campaignStatus == 'cancelled') {
            timer.cancel();
            state = state.copyWith(
              isSending: false,
              isPolling: false,
              activeCampaignId: null,
              logs: [
                ...state.logs,
                '[Hệ thống] Chiến dịch $campaignStatus. Thành công: $success, Thất bại: $failed, Đã hủy: $cancelled',
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
      state = state.copyWith(
        logs: [...state.logs, '[Hệ thống] Đang gửi yêu cầu hủy...'],
      );
      await _repository.cancelCampaign(campaignId);
      // Polling will catch the 'cancelled' state and clean up
    } catch (e) {
      state = state.copyWith(
        complianceError: 'Không thể hủy chiến dịch: ${e.toString()}',
      );
    }
  }
}

final bulkMessagingProvider =
    StateNotifierProvider<BulkMessagingNotifier, BulkMessagingState>((ref) {
      final repository = BulkCampaignRepository();
      return BulkMessagingNotifier(ref, repository);
    });
