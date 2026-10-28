import 'package:alpha_crm/features/devices/providers/crm_device_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses paired mobile users from active Windows device', () {
    final parsed = parseCrmDeviceList([
      {
        '_id': 'pc-1',
        'displayName': 'Office PC',
        'platform': 'windows',
        'status': 'active',
        'pairedMobileUserIds': ['user-a', 'user-b'],
      },
    ]);

    expect(parsed.deviceId, 'pc-1');
    expect(parsed.isPaired, isTrue);
    expect(parsed.pairedDevices, hasLength(2));
    expect(parsed.pairedDevices.first.id, 'user-a');
    expect(parsed.pairedDevices.first.displayName, 'Thiết bị di động 1');
  });

  test('does not treat an unpaired active Windows device as paired', () {
    final parsed = parseCrmDeviceList([
      {
        '_id': 'pc-1',
        'displayName': 'Office PC',
        'platform': 'windows',
        'status': 'active',
        'pairedMobileUserIds': [],
      },
    ]);

    expect(parsed.deviceId, 'pc-1');
    expect(parsed.isPaired, isFalse);
    expect(parsed.pairedDevices, isEmpty);
  });

  test('builds confirm payload from QR pairing JSON token', () {
    final payload = buildPairingConfirmPayload(
      '{"type":"alpha_crm_pairing","pairingToken":"qr-token-123"}',
    );

    expect(payload, {'qrToken': 'qr-token-123'});
  });

  test('builds confirm payload from six digit pairing code', () {
    final payload = buildPairingConfirmPayload('123 456');

    expect(payload, {'pairingCode': '123456'});
  });

  test('mobile remote disconnect never targets the PC lifecycle route', () {
    final request = buildRemoteDisconnectRequest(mobileUserId: 'mobile-user');

    expect(request.path, '/crm/pairing/revoke');
    expect(request.path, isNot(contains('/devices/')));
    expect(request.path, isNot(contains('/disable')));
    expect(request.body, {'mobileUserId': 'mobile-user'});
  });

  group('normalizePairingInput & buildPairingConfirmPayload edge cases', () {
    const sample48Hex = '0123456789abcdef0123456789abcdef0123456789abcdef';

    test('1. accepts hyphenated, spaced, and dotted 6-digit codes', () {
      expect(normalizePairingInput('123-456'), {'pairingCode': '123456'});
      expect(normalizePairingInput(' 12 3-456 '), {'pairingCode': '123456'});
      expect(normalizePairingInput('123.456'), {'pairingCode': '123456'});
      expect(buildPairingConfirmPayload('123-456'), {'pairingCode': '123456'});
    });

    test('2. rejects signed 5-digit strings (-12345, +12345) and wrong-length codes', () {
      expect(normalizePairingInput('-12345'), isNull);
      expect(normalizePairingInput('+12345'), isNull);
      expect(normalizePairingInput('12345'), isNull);
      expect(normalizePairingInput('1234567'), isNull);
    });

    test('3. parses JSON qrToken, pairingToken, pairingCode, and code fields', () {
      expect(
        normalizePairingInput(
          '{"type":"alpha_crm_pairing","pairingToken":"$sample48Hex"}',
        ),
        {'qrToken': sample48Hex},
      );
      expect(
        normalizePairingInput('{"qrToken":"$sample48Hex"}'),
        {'qrToken': sample48Hex},
      );
      expect(
        normalizePairingInput('{"pairingCode":"654-321"}'),
        {'pairingCode': '654321'},
      );
      expect(
        normalizePairingInput('{"code":"654321"}'),
        {'pairingCode': '654321'},
      );
    });

    test('4. maps 6-digit JSON pairingToken fallback to pairingCode instead of qrToken', () {
      expect(
        normalizePairingInput(
          '{"type":"alpha_crm_pairing","pairingToken":"123456"}',
        ),
        {'pairingCode': '123456'},
      );
      expect(
        buildPairingConfirmPayload(
          '{"type":"alpha_crm_pairing","pairingToken":"123456"}',
        ),
        {'pairingCode': '123456'},
      );
    });

    test('5. parses alphacrm/http/https pairing URLs and rejects unsupported schemes or missing params', () {
      expect(
        normalizePairingInput('alphacrm://pair?code=654-321'),
        {'pairingCode': '654321'},
      );
      expect(
        normalizePairingInput('https://crm.alpha.studio/pair?pairingCode=654321'),
        {'pairingCode': '654321'},
      );
      expect(
        normalizePairingInput('alphacrm://pair?qrToken=$sample48Hex'),
        {'qrToken': sample48Hex},
      );
      expect(
        normalizePairingInput('alphacrm://pair?token=$sample48Hex'),
        {'qrToken': sample48Hex},
      );
      expect(
        normalizePairingInput('https://crm.alpha.studio/pair?foo=bar'),
        isNull,
      );
      expect(
        normalizePairingInput('orca://pair?code=123456'),
        isNull,
      );
    });

    test('6. accepts 16+ char single-line token fallback and rejects >4096 char inputs', () {
      expect(
        normalizePairingInput('raw_qr_token_value_16chars'),
        {'qrToken': 'raw_qr_token_value_16chars'},
      );
      expect(normalizePairingInput('short_token'), isNull);
      expect(normalizePairingInput('a' * 4097), isNull);
    });
  });
}
