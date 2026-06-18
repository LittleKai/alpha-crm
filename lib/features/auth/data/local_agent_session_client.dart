import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../shared/utils/app_logger.dart';
import '../models/crm_login_result.dart';

abstract interface class LocalAgentSessionGateway {
  Future<LocalAgentSyncResult> sync({
    required String token,
    required String userId,
    bool forceReplace,
    String? displayName,
    String? machineFingerprint,
  });

  Future<void> logout({required String token});

  Stream<LocalAgentSessionEvent> events();
}

class LocalAgentSessionClient implements LocalAgentSessionGateway {
  final http.Client _client;
  final Uri _baseUri;
  final bool _isSupportedPlatform;

  LocalAgentSessionClient({
    http.Client? client,
    String baseUrl = 'http://127.0.0.1:8787',
    bool? isSupportedPlatform,
  }) : _client = client ?? http.Client(),
       _baseUri = Uri.parse(baseUrl),
       _isSupportedPlatform =
           isSupportedPlatform ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);

  @override
  Future<LocalAgentSyncResult> sync({
    required String token,
    required String userId,
    bool forceReplace = false,
    String? displayName,
    String? machineFingerprint,
  }) async {
    if (!_isSupportedPlatform) {
      return const LocalAgentActive('remote-only');
    }

    try {
      final response = await _client.post(
        _baseUri.resolve('/local/auth/sync'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'userId': userId,
          'force': forceReplace,
          'displayName': displayName ?? _defaultDisplayName(),
          'machineFingerprint':
              machineFingerprint ?? _defaultMachineFingerprint(),
        }),
      );
      final body = _decodeBody(response.body);
      AppLogger().warning(
        '[LocalAgentSync] /local/auth/sync → HTTP ${response.statusCode}, '
        'code=${body['code']}, success=${body['success']}, '
        'msg=${body['message']}',
      );
      if (response.statusCode == 409 &&
          body['code'] == 'DEVICE_ALREADY_ACTIVE') {
        final rawData = body['data'];
        final data = rawData is Map ? rawData : const {};
        final rawDevice = data['device'];
        final device = rawDevice is Map ? rawDevice : data;
        return LocalAgentConflict(
          ActiveDeviceSummary(
            displayName: device['displayName']?.toString(),
            lastSeenAt: DateTime.tryParse(
              device['lastSeenAt']?.toString() ?? '',
            ),
          ),
        );
      }
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          body['success'] == true) {
        final data = body['data'];
        final deviceId = data is Map ? data['deviceId']?.toString() : null;
        if (deviceId != null && deviceId.isNotEmpty) {
          return LocalAgentActive(deviceId);
        }
      }
      return LocalAgentUnavailable(
        body['message']?.toString() ?? 'Local CRM agent rejected the session.',
      );
    } catch (error) {
      AppLogger().warning('[LocalAgentSync] sync ngoại lệ: $error');
      return LocalAgentUnavailable(error.toString());
    }
  }

  @override
  Future<void> logout({required String token}) async {
    if (!_isSupportedPlatform) {
      return;
    }
    try {
      await _client.post(
        _baseUri.resolve('/local/auth/logout'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'token': token}),
      );
    } catch (_) {
      // Cloud logout remains usable when the local bridge is unavailable.
    }
  }

  @override
  Stream<LocalAgentSessionEvent> events() async* {
    if (!_isSupportedPlatform) {
      return;
    }
    final request = http.Request('GET', _baseUri.resolve('/local/events'));
    request.headers['Accept'] = 'text/event-stream';
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw HttpException(
        'Local session event stream returned ${response.statusCode}.',
      );
    }
    yield* parseSseLines(
      response.stream.transform(utf8.decoder).transform(const LineSplitter()),
    );
  }

  static Stream<LocalAgentSessionEvent> parseSseLines(
    Stream<String> lines,
  ) async* {
    String? eventName;
    String? data;
    await for (final line in lines) {
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data = line.substring(5).trim();
      } else if (line.isEmpty) {
        if (eventName == 'session.revoked' && data != null) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map && decoded['code'] == 'DEVICE_REVOKED') {
              yield LocalSessionRevoked(
                reason:
                    decoded['reason']?.toString() ??
                    'This PC session was revoked.',
              );
            }
          } catch (_) {
            // Ignore malformed event frames.
          }
        }
        eventName = null;
        data = null;
      }
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) {
      return const {};
    }
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
  }

  String _defaultDisplayName() {
    try {
      return 'Windows (${Platform.localHostname})';
    } catch (_) {
      return 'Windows PC';
    }
  }

  String _defaultMachineFingerprint() {
    final values = <String>[
      Platform.localHostname,
      Platform.operatingSystem,
      Platform.operatingSystemVersion,
      Platform.environment['COMPUTERNAME'] ?? '',
      Platform.environment['USERNAME'] ?? '',
    ];
    return sha256.convert(utf8.encode(values.join('|'))).toString();
  }
}
