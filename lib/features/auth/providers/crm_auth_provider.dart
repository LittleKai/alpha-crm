import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/api/crm_cloud_api.dart';
import '../../../shared/auth/crm_auth_token_store.dart';
import '../../../shared/auth/web_auth_bridge.dart';
import '../../../shared/utils/app_logger.dart';
import '../data/local_agent_session_client.dart';
import '../models/crm_login_result.dart';

abstract interface class CrmAuthGateway {
  Future<Map<String, dynamic>> get(String path);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body);
}

final class DefaultCrmAuthGateway implements CrmAuthGateway {
  const DefaultCrmAuthGateway();

  @override
  Future<Map<String, dynamic>> get(String path) => CrmCloudApi.get(path);

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      CrmCloudApi.post(path, body);
}

abstract interface class CrmTokenStore {
  Future<void> saveToken(String token);

  Future<String?> getToken();

  Future<void> deleteToken();
}

final class DefaultCrmTokenStore implements CrmTokenStore {
  const DefaultCrmTokenStore();

  @override
  Future<void> saveToken(String token) => CrmAuthTokenStore.saveToken(token);

  @override
  Future<String?> getToken() => CrmAuthTokenStore.getToken();

  @override
  Future<void> deleteToken() => CrmAuthTokenStore.deleteToken();
}

class CrmUserState {
  final String id;
  final String? email;
  final String? name;
  final String? role;
  final String? avatar;

  const CrmUserState({
    this.id = '',
    this.email,
    this.name,
    this.role,
    this.avatar,
  });

  factory CrmUserState.fromJson(Map<String, dynamic> json) {
    return CrmUserState(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      email: json['email']?.toString(),
      name: json['name']?.toString(),
      role: json['role']?.toString(),
      avatar: json['avatar']?.toString(),
    );
  }
}

class CrmAuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? token;
  final CrmUserState? user;
  final String? subscriptionStatus;
  final int includedAiRemaining;
  final int extraAiRemaining;
  final int creditBalance;
  final String? errorText;

  /// Khác null khi phiên trên máy này vừa bị thu hồi và đang chờ user quyết định
  /// (dùng máy này & thu hồi máy kia, hay đăng xuất). Giữ phiên hiện tại để có
  /// thể "đòi lại" thay vì văng thẳng về login.
  final String? deviceRevokedReason;

  /// Khác null khi KHÔI PHỤC phiên (lúc mở app) phát hiện tài khoản đã đạt giới
  /// hạn thiết bị (máy khác đang active). Dùng để hiện dialog "thay thế thiết bị
  /// cũ" thay vì văng im lặng về login.
  final ActiveDeviceSummary? pendingDeviceConflict;

  const CrmAuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.token,
    this.user,
    this.subscriptionStatus,
    this.includedAiRemaining = 0,
    this.extraAiRemaining = 0,
    this.creditBalance = 0,
    this.errorText,
    this.deviceRevokedReason,
    this.pendingDeviceConflict,
  });

  CrmAuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? token,
    CrmUserState? user,
    String? subscriptionStatus,
    int? includedAiRemaining,
    int? extraAiRemaining,
    int? creditBalance,
    String? errorText,
    String? deviceRevokedReason,
    ActiveDeviceSummary? pendingDeviceConflict,
  }) {
    return CrmAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      token: token ?? this.token,
      user: user ?? this.user,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      includedAiRemaining: includedAiRemaining ?? this.includedAiRemaining,
      extraAiRemaining: extraAiRemaining ?? this.extraAiRemaining,
      creditBalance: creditBalance ?? this.creditBalance,
      errorText: errorText,
      deviceRevokedReason: deviceRevokedReason,
      pendingDeviceConflict: pendingDeviceConflict,
    );
  }
}

class CrmAuthNotifier extends StateNotifier<CrmAuthState> {
  final CrmAuthGateway _cloudApi;
  final LocalAgentSessionGateway _localAgent;
  final CrmTokenStore _tokenStore;
  final bool _isWindows;
  StreamSubscription<LocalAgentSessionEvent>? _eventSubscription;
  String? _pendingToken;

  CrmAuthNotifier({
    CrmAuthGateway cloudApi = const DefaultCrmAuthGateway(),
    LocalAgentSessionGateway? localAgent,
    CrmTokenStore tokenStore = const DefaultCrmTokenStore(),
    bool? isWindows,
    bool autoInitialize = true,
  }) : _cloudApi = cloudApi,
       _localAgent = localAgent ?? LocalAgentSessionClient(),
       _tokenStore = tokenStore,
       _isWindows =
           isWindows ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows),
       super(const CrmAuthState()) {
    if (autoInitialize) {
      unawaited(_initialize());
    }
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    var receivedWebToken = false;
    if (kIsWeb) {
      setupWebAuthListener(
        onTokenReceived: (token) async {
          receivedWebToken = true;
          await setTokenAndFetchUser(token);
        },
      );
      Future.delayed(const Duration(seconds: 3), () async {
        if (!receivedWebToken && mounted) {
          await _checkLocalToken();
        }
      });
      return;
    }
    await _checkLocalToken();
  }

  Future<void> _checkLocalToken() async {
    final token = await _tokenStore.getToken();
    if (token == null || token.isEmpty) {
      state = const CrmAuthState();
      return;
    }
    // Token restoration: tolerate local backend being temporarily unavailable
    await _authenticateToken(token, isRestoration: true);
  }

  Future<void> setTokenAndFetchUser(String token) async {
    await _authenticateToken(token);
  }

  Future<CrmLoginResult> login(String email, String password) async {
    state = const CrmAuthState(isLoading: true);
    final response = await _cloudApi.post('/auth/login', {
      'email': email,
      'password': password,
    });
    final data = response['data'];
    final token = data is Map ? data['token']?.toString() : null;
    if (response['success'] != true || token == null || token.isEmpty) {
      final message =
          response['message']?.toString() ??
          'Email hoặc mật khẩu không chính xác.';
      state = CrmAuthState(errorText: message);
      return CrmLoginFailure(message);
    }
    return _authenticateToken(token);
  }

  Future<CrmLoginResult> confirmDeviceReplacement() async {
    final token = _pendingToken;
    if (token == null) {
      const message = 'Không có phiên đăng nhập đang chờ thay thế thiết bị.';
      state = const CrmAuthState(errorText: message);
      return const CrmLoginFailure(message);
    }
    return _authenticateToken(token, forceReplace: true);
  }

  Future<void> cancelPendingLogin() async {
    _pendingToken = null;
    await _tokenStore.deleteToken();
    state = const CrmAuthState();
  }

  Future<CrmLoginResult> _authenticateToken(
    String token, {
    bool forceReplace = false,
    bool isRestoration = false,
  }) async {
    state = const CrmAuthState(isLoading: true);

    // The current cloud API reads its bearer token from the shared token store.
    // Pending conflict tokens are removed again before returning to the UI.
    await _tokenStore.saveToken(token);
    final profile = await _loadCloudProfile();
    if (profile == null) {
      await _tokenStore.deleteToken();
      AppLogger().warning(
        '[CrmAuthNotifier] KICK: _loadCloudProfile null → xoá token, về login '
        '(restoration=$isRestoration, force=$forceReplace).',
      );
      const message = 'Không thể xác minh tài khoản Alpha Studio.';
      state = const CrmAuthState(errorText: message);
      return const CrmLoginFailure(message);
    }

    AppLogger().warning(
      '[CrmAuthNotifier] _authenticateToken: profile OK, isWindows=$_isWindows, '
      'restoration=$isRestoration, force=$forceReplace → gọi local sync...',
    );
    if (_isWindows) {
      final localResult = await _localAgent.sync(
        token: token,
        userId: profile.user.id,
        forceReplace: forceReplace,
      );
      AppLogger().warning(
        '[CrmAuthNotifier] local sync kết quả: ${localResult.runtimeType}',
      );
      if (localResult is LocalAgentConflict) {
        _pendingToken = token;
        await _tokenStore.deleteToken();
        if (isRestoration) {
          // Khi KHÔI PHỤC phiên không có UI nào chờ kết quả → đẩy conflict qua
          // state để DeviceConflictGate hiện dialog "thay thế thiết bị cũ".
          // Trước đây giá trị trả về bị bỏ qua → văng im lặng về login.
          AppLogger().warning(
            '[CrmAuthNotifier] KICK→CONFLICT: khôi phục phiên gặp giới hạn '
            'thiết bị (máy khác đang active) → hiện dialog thay thế.',
          );
          state = CrmAuthState(pendingDeviceConflict: localResult.device);
        } else {
          state = const CrmAuthState();
        }
        return CrmLoginDeviceConflict(localResult.device);
      }
      if (localResult is LocalAgentUnavailable) {
        if (isRestoration) {
          // Khi khôi phục phiên cũ, cho phép đăng nhập ngay cả khi backend
          // chưa sẵn sàng. Retry đồng bộ local agent ở nền sau.
          debugPrint(
            '[CrmAuthNotifier] Local agent chưa sẵn sàng khi khôi phục phiên. '
            'Cho phép đăng nhập và retry ở nền.',
          );
          _scheduleLocalAgentRetry(token, profile.user.id);
        } else {
          await _tokenStore.deleteToken();
          AppLogger().warning(
            '[CrmAuthNotifier] KICK: local agent unavailable khi đăng nhập mới '
            '→ xoá token, về login. Lý do: ${localResult.message}',
          );
          final message =
              'Không thể kết nối dịch vụ CRM trên máy này: '
              '${localResult.message}';
          state = CrmAuthState(errorText: message);
          return CrmLoginFailure(message);
        }
      }
    }

    _pendingToken = null;
    await _tokenStore.saveToken(token);
    AppLogger().info(
      '[CrmAuthNotifier] LOGIN OK → authenticated=true '
      '(restoration=$isRestoration, force=$forceReplace). Bắt đầu lắng nghe '
      'sự kiện thu hồi (SSE).',
    );
    state = CrmAuthState(
      isAuthenticated: true,
      token: token,
      user: profile.user,
      subscriptionStatus: profile.subscriptionStatus,
      includedAiRemaining: profile.includedAiRemaining,
      extraAiRemaining: profile.extraAiRemaining,
      creditBalance: profile.creditBalance,
    );
    _subscribeToLocalEvents();
    return const CrmLoginSuccess();
  }

  /// Retry đồng bộ local agent ở nền khi token restoration thành công nhưng
  /// backend chưa kịp khởi động. Thử tối đa 10 lần, mỗi lần cách 3 giây.
  void _scheduleLocalAgentRetry(String token, String userId) {
    int attempt = 0;
    const maxAttempts = 10;
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      attempt++;
      if (!mounted || attempt > maxAttempts) {
        timer.cancel();
        return;
      }
      try {
        final result = await _localAgent.sync(
          token: token,
          userId: userId,
        );
        if (result is LocalAgentActive) {
          debugPrint(
            '[CrmAuthNotifier] Local agent đồng bộ thành công (lần $attempt).',
          );
          timer.cancel();
        } else if (result is LocalAgentConflict) {
          debugPrint(
            '[CrmAuthNotifier] Local agent phát hiện conflict khi retry.',
          );
          timer.cancel();
        }
      } catch (_) {
        // Tiếp tục retry
      }
    });
  }

  Future<_CloudProfile?> _loadCloudProfile() async {
    final meResult = await _cloudApi.get('/auth/me');
    if (meResult['success'] != true || meResult['data'] == null) {
      return null;
    }
    final meData = meResult['data'];
    if (meData is! Map) {
      return null;
    }
    final rawUser = meData['user'] is Map ? meData['user'] : meData;
    final user = CrmUserState.fromJson(Map<String, dynamic>.from(rawUser));
    if (user.id.isEmpty) {
      return null;
    }
    final creditBalance =
        int.tryParse(
          (meData['balance'] ?? rawUser['balance'])?.toString() ?? '0',
        ) ??
        0;

    final subResult = await _cloudApi.get('/crm/subscription/me');
    var subscriptionStatus = 'none';
    if (subResult['success'] == true && subResult['data'] is Map) {
      final data = subResult['data'] as Map;
      final subscription = data['subscription'];
      subscriptionStatus = subscription is Map
          ? subscription['status']?.toString() ?? 'none'
          : data['active'] == true
          ? 'active'
          : 'none';
    }

    final quotaResult = await _cloudApi.get('/crm/quota');
    var includedRemaining = 0;
    var extraRemaining = 0;
    if (quotaResult['success'] == true && quotaResult['data'] is Map) {
      final data = quotaResult['data'] as Map;
      final limit =
          int.tryParse(data['includedAiLimit']?.toString() ?? '0') ?? 0;
      final used = int.tryParse(data['includedAiUsed']?.toString() ?? '0') ?? 0;
      includedRemaining = (limit - used).clamp(0, limit);
      extraRemaining =
          int.tryParse(data['extraAiRemaining']?.toString() ?? '0') ?? 0;
    }

    return _CloudProfile(
      user: user,
      subscriptionStatus: subscriptionStatus,
      includedAiRemaining: includedRemaining,
      extraAiRemaining: extraRemaining,
      creditBalance: creditBalance,
    );
  }

  void _subscribeToLocalEvents() {
    if (!_isWindows) {
      return;
    }
    unawaited(_eventSubscription?.cancel());
    AppLogger().info('[CrmAuthNotifier] Mở stream SSE /local/events để nhận thu hồi.');
    _eventSubscription = _localAgent.events().listen(
      (event) {
        if (event is LocalSessionRevoked) {
          unawaited(_handleRevocation(event));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger().warning(
          '[CrmAuthNotifier] Stream SSE /local/events lỗi/đứt: $error',
        );
      },
      onDone: () {
        AppLogger().warning('[CrmAuthNotifier] Stream SSE /local/events đã đóng.');
      },
    );
  }

  Future<void> _handleRevocation(LocalSessionRevoked event) async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    if (!mounted) {
      return;
    }
    // KHÔNG văng thẳng về login. Giữ token để có thể "đòi lại" máy này, và bật
    // cờ deviceRevokedReason để UI hiện dialog xác nhận (dùng máy này / đăng xuất).
    AppLogger().warning(
      '[CrmAuthNotifier] Nhận session.revoked → hiện dialog xác nhận '
      '(giữ phiên, KHÔNG đăng xuất). Lý do: ${event.reason}',
    );
    _pendingToken = state.token;
    state = state.copyWith(deviceRevokedReason: event.reason);
  }

  /// User chọn "Dùng máy này": đăng ký lại có force để thu hồi thiết bị kia và
  /// tiếp tục phiên trên máy này.
  Future<CrmLoginResult> reclaimRevokedDevice() async {
    final token = state.token ?? _pendingToken;
    if (token == null) {
      await logout();
      return const CrmLoginFailure(
        'Phiên đã hết hạn, vui lòng đăng nhập lại.',
      );
    }
    return _authenticateToken(token, forceReplace: true);
  }

  /// User chọn "Đăng xuất" sau khi bị thu hồi: rời phiên, về màn đăng nhập.
  Future<void> dismissRevokedDevice() async {
    await logout();
  }

  Future<void> logout() async {
    final token = state.token ?? _pendingToken;
    AppLogger().info(
      '[CrmAuthNotifier] logout() được gọi → xoá token, về login.',
      null,
      StackTrace.current,
    );
    state = state.copyWith(isLoading: true);
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    if (_isWindows && token != null) {
      await _localAgent.logout(token: token);
    }
    _pendingToken = null;
    await _tokenStore.deleteToken();
    state = const CrmAuthState();
  }

  Future<void> refreshSubscription() async {
    if (!state.isAuthenticated) {
      return;
    }
    final profile = await _loadCloudProfile();
    if (profile == null || !mounted) {
      return;
    }
    state = CrmAuthState(
      isAuthenticated: true,
      token: state.token,
      user: profile.user,
      subscriptionStatus: profile.subscriptionStatus,
      includedAiRemaining: profile.includedAiRemaining,
      extraAiRemaining: profile.extraAiRemaining,
      creditBalance: profile.creditBalance,
    );
  }

  @override
  void dispose() {
    unawaited(_eventSubscription?.cancel());
    super.dispose();
  }
}

class _CloudProfile {
  final CrmUserState user;
  final String subscriptionStatus;
  final int includedAiRemaining;
  final int extraAiRemaining;
  final int creditBalance;

  const _CloudProfile({
    required this.user,
    required this.subscriptionStatus,
    required this.includedAiRemaining,
    required this.extraAiRemaining,
    required this.creditBalance,
  });
}

final crmAuthProvider = StateNotifierProvider<CrmAuthNotifier, CrmAuthState>((
  ref,
) {
  return CrmAuthNotifier();
});
