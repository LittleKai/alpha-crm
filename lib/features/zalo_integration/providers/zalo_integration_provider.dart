import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../shared/utils/image_helper.dart';
import '../data/zalo_integration_api.dart';

class ZaloConnectedAccount {
  final String id;
  final String _label;
  final String zaloLabel;
  final String nickname;
  final bool connected;
  final bool listenerRunning;
  final String avatarUrl;
  final String proxy;
  final bool blockSeen;
  final bool blockTyping;
  // 'connected' | 'disconnected_expired'. Reason is set when the Zalo session
  // was force-revoked (duplicate login / kicked from phone).
  final String status;
  final String disconnectReason;

  const ZaloConnectedAccount({
    required this.id,
    required String label,
    this.zaloLabel = '',
    this.nickname = '',
    required this.connected,
    required this.listenerRunning,
    this.avatarUrl = '',
    this.proxy = '',
    this.blockSeen = false,
    this.blockTyping = false,
    this.status = 'connected',
    this.disconnectReason = '',
  }) : _label = label;

  String get label => nickname.trim().isEmpty ? _label : nickname;

  String get originalLabel => zaloLabel.trim().isEmpty ? _label : zaloLabel;

  bool get isExpired => status == 'disconnected_expired';
}

class ZaloIntegrationState {
  final bool isLoading;
  // True trong cửa sổ khởi động: backend đang lên HOẶC vừa lên nhưng chưa nạp
  // xong pool tài khoản (zca-js khôi phục phiên bất đồng bộ). Dùng để UI hiện
  // "đang tải" thay vì vội kết luận chưa có tài khoản.
  final bool isInitializing;
  final bool isConnected;
  final bool isBackendActive;
  final String? serviceVersion;
  final String mode;
  final String? accountType;
  final String? accountLabel;
  final bool listenerRunning;
  final String? lastEventAt;
  final String? errorText;
  final List<ZaloConnectedAccount> accounts;
  final String? agentError;

  const ZaloIntegrationState({
    this.isLoading = false,
    this.isInitializing = false,
    this.isConnected = false,
    this.isBackendActive = false,
    this.serviceVersion,
    this.mode = 'disconnected',
    this.accountType,
    this.accountLabel,
    this.listenerRunning = false,
    this.lastEventAt,
    this.errorText,
    this.accounts = const [],
    this.agentError,
  });

  ZaloIntegrationState copyWith({
    bool? isLoading,
    bool? isInitializing,
    bool? isConnected,
    bool? isBackendActive,
    String? serviceVersion,
    String? mode,
    String? accountType,
    String? accountLabel,
    bool? listenerRunning,
    String? lastEventAt,
    String? errorText,
    List<ZaloConnectedAccount>? accounts,
    String? agentError,
  }) {
    return ZaloIntegrationState(
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      isConnected: isConnected ?? this.isConnected,
      isBackendActive: isBackendActive ?? this.isBackendActive,
      serviceVersion: serviceVersion ?? this.serviceVersion,
      mode: mode ?? this.mode,
      accountType: accountType ?? this.accountType,
      accountLabel: accountLabel ?? this.accountLabel,
      listenerRunning: listenerRunning ?? this.listenerRunning,
      lastEventAt: lastEventAt ?? this.lastEventAt,
      errorText: errorText,
      accounts: accounts ?? this.accounts,
      agentError: agentError,
    );
  }
}

class ZaloIntegrationNotifier extends StateNotifier<ZaloIntegrationState> {
  final Ref _ref;
  ZaloIntegrationApi? _api;
  Timer? _pollingTimer;
  Timer? _initRetryTimer;
  int _initAttempts = 0;

  /// Số lần thử lại tối đa trong cửa sổ khởi động (mỗi 2s) trước khi kết luận
  /// thật sự chưa có tài khoản. ~30s đủ cho backend lên + nạp xong pool zca-js.
  static const int _maxInitAttempts = 15;
  static const Duration _initRetryInterval = Duration(seconds: 2);

  ZaloIntegrationNotifier(this._ref) : super(const ZaloIntegrationState());

  ZaloIntegrationApi _getApi() {
    final baseUrl = _ref.read(settingsProvider).settings.zaloBackendBaseUrl;
    if (_api == null || _api!.baseUrl != baseUrl) {
      _api?.dispose();
      _api = ZaloIntegrationApi(baseUrl: baseUrl);
    }
    return _api!;
  }

  void startPollingBackend() {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      debugPrint(
        '[ZaloIntegrationNotifier] Bỏ qua kiểm tra kết nối local backend trên Mobile.',
      );
      return;
    }
    _pollingTimer?.cancel();
    _pollingTimer = null;

    // Cửa sổ khởi động: backend trả /health=ok TRƯỚC khi nạp xong pool tài khoản
    // (zca-js khôi phục phiên bất đồng bộ sau khi Flutter sync session). Vì vậy
    // lần check đầu có thể ra 0 tài khoản dù thực tế đã đăng nhập. Thử lại có
    // giới hạn cho đến khi có tài khoản hoặc hết hạn mức rồi mới kết luận.
    state = state.copyWith(isInitializing: true);
    _initAttempts = 0;
    _runInitCheckLoop();
  }

  Future<void> _runInitCheckLoop() async {
    _initRetryTimer?.cancel();
    _initRetryTimer = null;

    await checkConnection(showLoading: false);
    _initAttempts++;

    // Đã có tài khoản → xong khởi động.
    if (state.isBackendActive && state.accounts.isNotEmpty) {
      _finishInitializing();
      return;
    }
    // Hết hạn mức thử lại → kết luận (có thể thật sự chưa có tài khoản).
    if (_initAttempts >= _maxInitAttempts) {
      debugPrint(
        '[ZALO-STARTUP-DEBUG] Hết hạn mức thử lại ($_initAttempts lần) — dừng poll khởi động.',
      );
      _finishInitializing();
      return;
    }
    // Backend chưa lên, hoặc lên rồi nhưng pool tài khoản chưa nạp xong → thử lại.
    _initRetryTimer = Timer(_initRetryInterval, _runInitCheckLoop);
  }

  void _finishInitializing() {
    _initRetryTimer?.cancel();
    _initRetryTimer = null;
    if (state.isInitializing) {
      state = state.copyWith(isInitializing: false);
    }
  }

  void stopPollingBackend() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _initRetryTimer?.cancel();
    _initRetryTimer = null;
    debugPrint('[ZaloIntegrationNotifier] Stopped backend polling timer.');
  }

  Future<void> checkConnection({bool showLoading = false}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, errorText: null);
    } else {
      state = state.copyWith(errorText: null);
    }

    debugPrint(
      '[ZALO-STARTUP-DEBUG] checkConnection() bắt đầu @ ${DateTime.now().toIso8601String()}',
    );
    try {
      final api = _getApi();
      final health = await api.healthCheck();
      debugPrint(
        '[ZALO-STARTUP-DEBUG] healthCheck -> status=${health['status']} (backend ${health['status'] == 'ok' ? 'SẴN SÀNG' : 'CHƯA SẴN SÀNG'})',
      );

      if (health['status'] == 'ok') {
        final status = await api.getZaloStatus();
        final accResponse = await api.fetchAccounts();
        debugPrint(
          '[ZALO-STARTUP-DEBUG] fetchAccounts -> success=${accResponse['success']} count=${(accResponse['accounts'] as List?)?.length ?? 'null'}',
        );
        final agentErr = health['agent']?['error']?.toString();

        List<ZaloConnectedAccount> activeAccounts = [];
        if (accResponse['success'] == true && accResponse['accounts'] != null) {
          final List<dynamic> rawAccs = accResponse['accounts'];
          final seenIds = <String>{};
          activeAccounts = rawAccs
              .map((item) {
                final settings = item['settings'] is Map
                    ? Map<String, dynamic>.from(item['settings'])
                    : const <String, dynamic>{};
                final id = item['id']?.toString() ?? '';
                final zaloLabel = item['label']?.toString() ?? 'Tài khoản';
                final nickname = _ref
                    .read(settingsProvider)
                    .settings
                    .nicknameForAccount(id);
                return ZaloConnectedAccount(
                  id: id,
                  zaloLabel: zaloLabel,
                  nickname: nickname ?? '',
                  label: item['label']?.toString() ?? 'Tài khoản',
                  connected: item['connected'] == true,
                  listenerRunning: item['listenerRunning'] == true,
                  avatarUrl: sanitizeImageUrl(item['avatar']?.toString() ?? ''),
                  proxy: settings['proxy']?.toString() ?? '',
                  blockSeen: settings['blockSeen'] == true,
                  blockTyping: settings['blockTyping'] == true,
                  status: item['status']?.toString() ?? 'connected',
                  disconnectReason: item['disconnectReason']?.toString() ?? '',
                );
              })
                .where((acc) => seenIds.add(acc.id))
                .toList();
          } else {
            activeAccounts = state.accounts;
          }

          final statusAccountId = status['accountId']?.toString() ?? '';
        var displayAccountLabel = status['accountLabel']?.toString();
        if (statusAccountId.isNotEmpty) {
          for (final account in activeAccounts) {
            if (account.id == statusAccountId) {
              displayAccountLabel = account.label;
              break;
            }
          }
        } else if (activeAccounts.length == 1) {
          displayAccountLabel = activeAccounts.first.label;
        }

        debugPrint(
          '[ZALO-STARTUP-DEBUG] -> set state với ${activeAccounts.length} tài khoản (THÀNH CÔNG)',
        );
        state = state.copyWith(
          isLoading: false,
          isBackendActive: true,
          isConnected: status['connected'] == true,
          serviceVersion: (health['version'] ?? status['version'])?.toString(),
          mode: (status['mode'] ?? 'disconnected').toString(),
          accountType: status['accountType']?.toString(),
          accountLabel: displayAccountLabel,
          listenerRunning: status['listenerRunning'] == true,
          lastEventAt: status['lastEventAt']?.toString(),
          accounts: activeAccounts,
          agentError: agentErr,
        );
      } else {
        debugPrint(
          '[ZALO-STARTUP-DEBUG] -> backend CHƯA SẴN SÀNG, set accounts=[] và KHÔNG thử lại (đây là nguyên nhân lần đầu trống)',
        );
        debugPrint(
          '[ZaloIntegrationNotifier] Health check returned non-ok status: $health',
        );
        state = state.copyWith(
          isLoading: false,
          isBackendActive: false,
          isConnected: false,
          errorText:
              health['error']?.toString() ?? 'Không thể kết nối tới backend.',
          accounts: const [],
          agentError: null,
        );
      }
    } catch (e, stack) {
      debugPrint(
        '[ZALO-STARTUP-DEBUG] -> EXCEPTION (backend chưa lên?), set accounts=[] và KHÔNG thử lại: $e',
      );
      debugPrint(
        '[ZaloIntegrationNotifier] Exception in checkConnection: $e\n$stack',
      );
      state = state.copyWith(
        isLoading: false,
        isBackendActive: false,
        isConnected: false,
        errorText: 'Lỗi kết nối: ${e.toString()}',
        accounts: const [],
        agentError: null,
      );
    }
  }

  Future<bool> deleteAccount(String accountId) async {
    try {
      final api = _getApi();
      final response = await api.deleteAccount(accountId);
      if (response['success'] == true) {
        await checkConnection();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateAccountSettings({
    required String accountId,
    required String nickname,
    required String proxy,
    required bool blockSeen,
    required bool blockTyping,
  }) async {
    await _ref
        .read(settingsProvider.notifier)
        .saveAccountNickname(accountId, nickname);
    _applyLocalAccountNicknames();
    try {
      final api = _getApi();
      final response = await api.updateAccountSettings(
        accountId: accountId,
        proxy: proxy,
        blockSeen: blockSeen,
        blockTyping: blockTyping,
      );
      if (response['success'] == true) {
        await checkConnection();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _applyLocalAccountNicknames() {
    final settings = _ref.read(settingsProvider).settings;
    state = state.copyWith(
      accounts: state.accounts
          .map(
            (account) => ZaloConnectedAccount(
              id: account.id,
              label: account.originalLabel,
              zaloLabel: account.originalLabel,
              nickname: settings.nicknameForAccount(account.id) ?? '',
              connected: account.connected,
              listenerRunning: account.listenerRunning,
              avatarUrl: account.avatarUrl,
              proxy: account.proxy,
              blockSeen: account.blockSeen,
              blockTyping: account.blockTyping,
              status: account.status,
              disconnectReason: account.disconnectReason,
            ),
          )
          .toList(),
    );
  }

  @override
  void dispose() {
    stopPollingBackend();
    _api?.dispose();
    super.dispose();
  }
}

final zaloIntegrationProvider =
    StateNotifierProvider<ZaloIntegrationNotifier, ZaloIntegrationState>((ref) {
      return ZaloIntegrationNotifier(ref);
    });
