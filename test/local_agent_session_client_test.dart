import 'dart:convert';

import 'package:alpha_crm/features/auth/data/local_agent_session_client.dart';
import 'package:alpha_crm/features/auth/models/crm_login_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sync maps 409 device conflict to a typed result', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/local/auth/sync');
      return http.Response(
        jsonEncode({
          'success': false,
          'code': 'DEVICE_ALREADY_ACTIVE',
          'data': {
            'device': {'displayName': 'PC-A'},
          },
        }),
        409,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = LocalAgentSessionClient(
      client: client,
      isSupportedPlatform: true,
    );
    final result = await api.sync(token: 'jwt', userId: 'user-1');

    expect(result, isA<LocalAgentConflict>());
    expect((result as LocalAgentConflict).device.displayName, 'PC-A');
  });

  test('connection failures remain unavailable rather than revoked', () async {
    final api = LocalAgentSessionClient(
      client: MockClient((_) => throw http.ClientException('offline')),
      isSupportedPlatform: true,
    );

    final result = await api.sync(token: 'jwt', userId: 'user-1');

    expect(result, isA<LocalAgentUnavailable>());
  });

  test('event parser emits explicit session revoked events', () async {
    final events = LocalAgentSessionClient.parseSseLines(
      Stream.fromIterable([
        'event: session.revoked',
        'data: {"code":"DEVICE_REVOKED","reason":"replaced_by_new_pc"}',
        '',
      ]),
    );

    expect(
      await events.first,
      const LocalSessionRevoked(reason: 'replaced_by_new_pc'),
    );
  });
}
