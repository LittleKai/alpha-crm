import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/api/crm_cloud_api.dart';
import '../../../shared/auth/crm_auth_token_store.dart';
import '../../../shared/auth/web_auth_bridge.dart';

class CrmUserState {
  final String? email;
  final String? name;
  final String? role;
  
  CrmUserState({this.email, this.name, this.role});
  
  factory CrmUserState.fromJson(Map<String, dynamic> json) {
    return CrmUserState(
      email: json['email']?.toString(),
      name: json['name']?.toString(),
      role: json['role']?.toString(),
    );
  }
}

class CrmAuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? token;
  final CrmUserState? user;
  final String? subscriptionStatus; // 'active', 'expired', 'none'
  final int includedAiRemaining;
  final int extraAiRemaining;
  final String? errorText;

  const CrmAuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.token,
    this.user,
    this.subscriptionStatus,
    this.includedAiRemaining = 0,
    this.extraAiRemaining = 0,
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
      errorText: errorText,
    );
  }
}

class CrmAuthNotifier extends StateNotifier<CrmAuthState> {
  CrmAuthNotifier() : super(const CrmAuthState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    // 1. Đăng ký bộ lắng nghe Web SSO nếu chạy trên môi trường Web
    if (kIsWeb) {
      setupWebAuthListener(onTokenReceived: (token) async {
        debugPrint('[CrmAuthNotifier] Nhận SSO token từ postMessage.');
        await setTokenAndFetchUser(token);
      });
    }

    // 2. Khôi phục token đã lưu trước đó
    state = state.copyWith(isLoading: true);
    final token = await CrmAuthTokenStore.getToken();
    if (token != null && token.isNotEmpty) {
      await setTokenAndFetchUser(token);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> setTokenAndFetchUser(String token) async {
    state = state.copyWith(isLoading: true, token: token, errorText: null);
    await CrmAuthTokenStore.saveToken(token);
    
    // Gọi API lấy thông tin người dùng
    final meResult = await CrmCloudApi.get('/auth/me');
    if (meResult['success'] == true && meResult['data'] != null) {
      final user = CrmUserState.fromJson(meResult['data']);
      
      // Gọi API lấy trạng thái đăng ký CRM
      final subResult = await CrmCloudApi.get('/crm/subscription/me');
      String subStatus = 'none';
      
      if (subResult['success'] == true && subResult['data'] != null) {
        final data = subResult['data'];
        final subscription = data['subscription'];
        if (subscription != null) {
          subStatus = subscription['status']?.toString() ?? 'none';
        } else {
          final bool isActive = data['active'] == true;
          subStatus = isActive ? 'active' : 'none';
        }
      }

      // Gọi API lấy AI quota từ endpoint thực tế của Phase 1
      final quotaResult = await CrmCloudApi.get('/crm/quota');
      int incRemaining = 0;
      int extRemaining = 0;
      
      if (quotaResult['success'] == true && quotaResult['data'] != null) {
        final qData = quotaResult['data'];
        final int limit = qData['includedAiLimit'] is int ? qData['includedAiLimit'] : (int.tryParse(qData['includedAiLimit']?.toString() ?? '0') ?? 0);
        final int used = qData['includedAiUsed'] is int ? qData['includedAiUsed'] : (int.tryParse(qData['includedAiUsed']?.toString() ?? '0') ?? 0);
        incRemaining = limit - used;
        if (incRemaining < 0) incRemaining = 0;
        extRemaining = qData['extraAiRemaining'] is int ? qData['extraAiRemaining'] : (int.tryParse(qData['extraAiRemaining']?.toString() ?? '0') ?? 0);
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
        subscriptionStatus: subStatus,
        includedAiRemaining: incRemaining,
        extraAiRemaining: extRemaining,
      );
    } else {
      // Xóa token không hợp lệ
      await CrmAuthTokenStore.deleteToken();
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        token: null,
        user: null,
        subscriptionStatus: null,
      );
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorText: null);
    final response = await CrmCloudApi.post('/auth/login', {
      'email': email,
      'password': password,
    });

    if (response['success'] == true && response['data'] != null && response['data']['token'] != null) {
      final token = response['data']['token'].toString();
      await setTokenAndFetchUser(token);
      return true;
    } else {
      final msg = response['message'] ?? 'Email hoặc mật khẩu không chính xác.';
      state = state.copyWith(isLoading: false, errorText: msg);
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await CrmAuthTokenStore.deleteToken();
    state = const CrmAuthState();
  }
  
  Future<void> refreshSubscription() async {
    if (!state.isAuthenticated) return;
    
    final subResult = await CrmCloudApi.get('/crm/subscription/me');
    String subStatus = 'none';
    if (subResult['success'] == true && subResult['data'] != null) {
      final data = subResult['data'];
      final subscription = data['subscription'];
      if (subscription != null) {
        subStatus = subscription['status']?.toString() ?? 'none';
      } else {
        final bool isActive = data['active'] == true;
        subStatus = isActive ? 'active' : 'none';
      }
    }

    final quotaResult = await CrmCloudApi.get('/crm/quota');
    int incRemaining = 0;
    int extRemaining = 0;
    if (quotaResult['success'] == true && quotaResult['data'] != null) {
      final qData = quotaResult['data'];
      final int limit = qData['includedAiLimit'] is int ? qData['includedAiLimit'] : (int.tryParse(qData['includedAiLimit']?.toString() ?? '0') ?? 0);
      final int used = qData['includedAiUsed'] is int ? qData['includedAiUsed'] : (int.tryParse(qData['includedAiUsed']?.toString() ?? '0') ?? 0);
      incRemaining = limit - used;
      if (incRemaining < 0) incRemaining = 0;
      extRemaining = qData['extraAiRemaining'] is int ? qData['extraAiRemaining'] : (int.tryParse(qData['extraAiRemaining']?.toString() ?? '0') ?? 0);
    }

    state = state.copyWith(
      subscriptionStatus: subStatus,
      includedAiRemaining: incRemaining,
      extraAiRemaining: extRemaining,
    );
  }
}

final crmAuthProvider = StateNotifierProvider<CrmAuthNotifier, CrmAuthState>((ref) {
  return CrmAuthNotifier();
});
