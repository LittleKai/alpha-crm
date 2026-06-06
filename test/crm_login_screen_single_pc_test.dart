import 'dart:async';

import 'package:alpha_crm/features/auth/data/local_agent_session_client.dart';
import 'package:alpha_crm/features/auth/models/crm_login_result.dart';
import 'package:alpha_crm/features/auth/presentation/screens/crm_login_screen.dart';
import 'package:alpha_crm/features/auth/providers/crm_auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Cloud implements CrmAuthGateway {
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
          'includedAiLimit': 1,
          'includedAiUsed': 0,
          'extraAiRemaining': 0,
        },
      },
      _ => {'success': false},
    };
  }

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
}

class _Local implements LocalAgentSessionGateway {
  @override
  Stream<LocalAgentSessionEvent> events() => const Stream.empty();

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
    return const LocalAgentConflict(ActiveDeviceSummary(displayName: 'PC-A'));
  }
}

class _Tokens implements CrmTokenStore {
  String? value;

  @override
  Future<void> deleteToken() async => value = null;

  @override
  Future<String?> getToken() async => value;

  @override
  Future<void> saveToken(String token) async => value = token;
}

void main() {
  testWidgets('device conflict shows replacement confirmation dialog', (
    tester,
  ) async {
    final notifier = CrmAuthNotifier(
      cloudApi: _Cloud(),
      localAgent: _Local(),
      tokenStore: _Tokens(),
      isWindows: true,
      autoInitialize: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [crmAuthProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: CrmLoginScreen()),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('crm-email')),
      'user@example.com',
    );
    await tester.enterText(find.byKey(const Key('crm-password')), 'password');
    await tester.tap(find.byKey(const Key('crm-login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Đăng xuất máy tính cũ?'), findsOneWidget);
    expect(find.textContaining('PC-A'), findsOneWidget);
  });
}
