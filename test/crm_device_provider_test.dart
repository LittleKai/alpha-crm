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
}
