import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/api/crm_cloud_api.dart';
import '../../../shared/auth/crm_auth_token_store.dart';
import '../../../shared/auth/web_auth_bridge.dart';
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
    await setTokenAndFetchUser(token);
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
  }) async {
    state = const CrmAuthState(isLoading: true);

    // The current cloud API reads its bearer token from the shared token store.
    // Pending conflict tokens are removed again before returning to the UI.
    await _tokenStore.saveToken(token);
    final profile = await _loadCloudProfile();
    if (profile == null) {
      await _tokenStore.deleteToken();
      const message = 'Không thể xác minh tài khoản Alpha Studio.';
      state = const CrmAuthState(errorText: message);
      return const CrmLoginFailure(message);
    }

    if (_isWindows) {
      final localResult = await _localAgent.sync(
        token: token,
        userId: profile.user.id,
        forceReplace: forceReplace,
      );
      if (localResult is LocalAgentConflict) {
        _pendingToken = token;
        await _tokenStore.deleteToken();
        state = const CrmAuthState();
        return CrmLoginDeviceConflict(localResult.device);
      }
      if (localResult is LocalAgentUnavailable) {
        await _tokenStore.deleteToken();
        final message =
            'Không thể kết nối dịch vụ CRM trên máy này: '
            '${localResult.message}';
        state = CrmAuthState(errorText: message);
        return CrmLoginFailure(message);
      }
    }

    _pendingToken = null;
    await _tokenStore.saveToken(token);
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
    _eventSubscription = _localAgent.events().listen(
      (event) {
        if (event is LocalSessionRevoked) {
          unawaited(_handleRevocation(event));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[CrmAuthNotifier] Local event stream unavailable: $error');
      },
    );
  }

  Future<void> _handleRevocation(LocalSessionRevoked event) async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _pendingToken = null;
    await _tokenStore.deleteToken();
    if (mounted) {
      state = CrmAuthState(
        errorText: 'Phiên trên máy tính này đã bị thu hồi: ${event.reason}',
      );
    }
  }

  Future<void> logout() async {
    final token = state.token ?? _pendingToken;
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
