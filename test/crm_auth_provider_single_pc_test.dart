import 'dart:async';

import 'package:alpha_crm/features/auth/data/local_agent_session_client.dart';
import 'package:alpha_crm/features/auth/models/crm_login_result.dart';
import 'package:alpha_crm/features/auth/providers/crm_auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCloudGateway implements CrmAuthGateway {
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    return {
      'success': true,
      'data': {'token': 'jwt'},
    };
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
    return switch (path) {
      '/auth/me' => {
        'success': true,
        'data': {
          'user': {'_id': 'user-1', 'email': 'user@example.com'},
        },
      },
      '/crm/subscription/me' => {
        'success': true,
        'data': {'active': true},
      },
      '/crm/quota' => {
        'success': true,
        'data': {
          'includedAiLimit': 1000,
          'includedAiUsed': 0,
          'extraAiRemaining': 0,
        },
      },
      _ => {'success': false},
    };
  }
}

class MemoryTokenStore implements CrmTokenStore {
  String? token;

  @override
  Future<void> deleteToken() async {
    token = null;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> saveToken(String value) async {
    token = value;
  }
}

class FakeLocalAgent implements LocalAgentSessionGateway {
  final StreamController<LocalAgentSessionEvent> controller =
      StreamController.broadcast();
  LocalAgentSyncResult result;

  FakeLocalAgent(this.result);

  @override
  Stream<LocalAgentSessionEvent> events() => controller.stream;

  @override
  Future<void> logout({required String token}) async {}

  @override
  Future<LocalAgentSyncResult> sync({
    required String token,
    required String userId,
    bool forceReplace = false,
    String? displayName,
    String? machineFingerprint,
  }) async {
    return result;
  }
}

void main() {
  test('Windows login returns conflict and stays unauthenticated', () async {
    final tokenStore = MemoryTokenStore();
    final local = FakeLocalAgent(
      const LocalAgentConflict(ActiveDeviceSummary(displayName: 'PC-A')),
    );
    final notifier = CrmAuthNotifier(
      cloudApi: FakeCloudGateway(),
      localAgent: local,
      tokenStore: tokenStore,
      isWindows: true,
      autoInitialize: false,
    );

    final result = await notifier.login('user@example.com', 'password');

    expect(result, isA<CrmLoginDeviceConflict>());
    expect(notifier.state.isAuthenticated, isFalse);
    expect(tokenStore.token, isNull);
  });

  test('revocation event clears authenticated state and token', () async {
    final tokenStore = MemoryTokenStore();
    final local = FakeLocalAgent(const LocalAgentActive('device-1'));
    final notifier = CrmAuthNotifier(
      cloudApi: FakeCloudGateway(),
      localAgent: local,
      tokenStore: tokenStore,
      isWindows: true,
      autoInitialize: false,
    );
    await notifier.login('user@example.com', 'password');

    local.controller.add(
      const LocalSessionRevoked(reason: 'replaced_by_new_pc'),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.isAuthenticated, isFalse);
    expect(tokenStore.token, isNull);
  });
}
