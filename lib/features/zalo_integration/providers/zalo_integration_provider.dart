import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../data/zalo_integration_api.dart';

class ZaloIntegrationState {
  final bool isLoading;
  final bool isConnected;
  final String? serviceVersion;
  final String mode;
  final String? accountType;
  final String? accountLabel;
  final bool listenerRunning;
  final String? lastEventAt;
  final String? errorText;

  const ZaloIntegrationState({
    this.isLoading = false,
    this.isConnected = false,
    this.serviceVersion,
    this.mode = 'disconnected',
    this.accountType,
    this.accountLabel,
    this.listenerRunning = false,
    this.lastEventAt,
    this.errorText,
  });

  ZaloIntegrationState copyWith({
    bool? isLoading,
    bool? isConnected,
    String? serviceVersion,
    String? mode,
    String? accountType,
    String? accountLabel,
    bool? listenerRunning,
    String? lastEventAt,
    String? errorText,
  }) {
    return ZaloIntegrationState(
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      serviceVersion: serviceVersion ?? this.serviceVersion,
      mode: mode ?? this.mode,
      accountType: accountType ?? this.accountType,
      accountLabel: accountLabel ?? this.accountLabel,
      listenerRunning: listenerRunning ?? this.listenerRunning,
      lastEventAt: lastEventAt ?? this.lastEventAt,
      errorText: errorText,
    );
  }
}

class ZaloIntegrationNotifier extends StateNotifier<ZaloIntegrationState> {
  final Ref _ref;
  ZaloIntegrationApi? _api;

  ZaloIntegrationNotifier(this._ref)
    : super(const ZaloIntegrationState());

  ZaloIntegrationApi _getApi() {
    final baseUrl = _ref.read(settingsProvider).settings.zaloBackendBaseUrl;
    _api?.dispose();
    _api = ZaloIntegrationApi(baseUrl: baseUrl);
    return _api!;
  }

  Future<void> checkConnection() async {
    state = state.copyWith(isLoading: true, errorText: null);

    try {
      final api = _getApi();
      final health = await api.healthCheck();

      if (health['status'] == 'ok') {
        final status = await api.getZaloStatus();
        state = state.copyWith(
          isLoading: false,
          isConnected: status['connected'] == true,
          serviceVersion: (health['version'] ?? status['version'])?.toString(),
          mode: (status['mode'] ?? 'disconnected').toString(),
          accountType: status['accountType']?.toString(),
          accountLabel: status['accountLabel']?.toString(),
          listenerRunning: status['listenerRunning'] == true,
          lastEventAt: status['lastEventAt']?.toString(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isConnected: false,
          errorText: health['error']?.toString() ?? 'Không thể kết nối tới backend.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isConnected: false,
        errorText: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  @override
  void dispose() {
    _api?.dispose();
    super.dispose();
  }
}

final zaloIntegrationProvider =
    StateNotifierProvider<ZaloIntegrationNotifier, ZaloIntegrationState>((ref) {
      return ZaloIntegrationNotifier(ref);
    });
