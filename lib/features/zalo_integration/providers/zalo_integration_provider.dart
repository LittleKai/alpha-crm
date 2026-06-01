import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../shared/utils/image_helper.dart';
import '../data/zalo_integration_api.dart';

class ZaloConnectedAccount {
  final String id;
  final String label;
  final bool connected;
  final bool listenerRunning;
  final String avatarUrl;

  const ZaloConnectedAccount({
    required this.id,
    required this.label,
    required this.connected,
    required this.listenerRunning,
    this.avatarUrl = '',
  });
}

class ZaloIntegrationState {
  final bool isLoading;
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

  const ZaloIntegrationState({
    this.isLoading = false,
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
  });

  ZaloIntegrationState copyWith({
    bool? isLoading,
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
  }) {
    return ZaloIntegrationState(
      isLoading: isLoading ?? this.isLoading,
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
    );
  }
}

class ZaloIntegrationNotifier extends StateNotifier<ZaloIntegrationState> {
  final Ref _ref;
  ZaloIntegrationApi? _api;
  Timer? _pollingTimer;

  ZaloIntegrationNotifier(this._ref)
    : super(const ZaloIntegrationState());

  ZaloIntegrationApi _getApi() {
    final baseUrl = _ref.read(settingsProvider).settings.zaloBackendBaseUrl;
    if (_api == null || _api!.baseUrl != baseUrl) {
      _api?.dispose();
      _api = ZaloIntegrationApi(baseUrl: baseUrl);
    }
    return _api!;
  }

  void startPollingBackend() {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      debugPrint('[ZaloIntegrationNotifier] Bỏ qua kiểm tra kết nối local backend trên Web/Mobile.');
      return;
    }
    _pollingTimer?.cancel();
    // Run an immediate check when starting
    checkConnection();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      checkConnection();
    });
    debugPrint('[ZaloIntegrationNotifier] Started backend polling timer (every 5s).');
  }

  void stopPollingBackend() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    debugPrint('[ZaloIntegrationNotifier] Stopped backend polling timer.');
  }

  Future<void> checkConnection() async {
    state = state.copyWith(isLoading: true, errorText: null);

    try {
      final api = _getApi();
      final health = await api.healthCheck();

      if (health['status'] == 'ok') {
        final status = await api.getZaloStatus();
        final accResponse = await api.fetchAccounts();

        List<ZaloConnectedAccount> activeAccounts = [];
        if (accResponse['success'] == true && accResponse['accounts'] != null) {
          final List<dynamic> rawAccs = accResponse['accounts'];
          activeAccounts = rawAccs.map((item) {
            return ZaloConnectedAccount(
              id: item['id']?.toString() ?? '',
              label: item['label']?.toString() ?? 'Tài khoản',
              connected: item['connected'] == true,
              listenerRunning: item['listenerRunning'] == true,
              avatarUrl: sanitizeImageUrl(item['avatar']?.toString() ?? ''),
            );
          }).toList();
        }

        state = state.copyWith(
          isLoading: false,
          isBackendActive: true,
          isConnected: status['connected'] == true,
          serviceVersion: (health['version'] ?? status['version'])?.toString(),
          mode: (status['mode'] ?? 'disconnected').toString(),
          accountType: status['accountType']?.toString(),
          accountLabel: status['accountLabel']?.toString(),
          listenerRunning: status['listenerRunning'] == true,
          lastEventAt: status['lastEventAt']?.toString(),
          accounts: activeAccounts,
        );
      } else {
        debugPrint('[ZaloIntegrationNotifier] Health check returned non-ok status: $health');
        state = state.copyWith(
          isLoading: false,
          isBackendActive: false,
          isConnected: false,
          errorText: health['error']?.toString() ?? 'Không thể kết nối tới backend.',
          accounts: const [],
        );
      }
    } catch (e, stack) {
      debugPrint('[ZaloIntegrationNotifier] Exception in checkConnection: $e\n$stack');
      state = state.copyWith(
        isLoading: false,
        isBackendActive: false,
        isConnected: false,
        errorText: 'Lỗi kết nối: ${e.toString()}',
        accounts: const [],
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
