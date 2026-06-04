import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/api/crm_cloud_api.dart';

class PairedDevice {
  final String id;
  final String displayName;
  final String platform;
  final String status;

  const PairedDevice({
    required this.id,
    required this.displayName,
    required this.platform,
    required this.status,
  });
}

class CrmDeviceState {
  final bool isLoading;
  final bool isPaired;
  final String? deviceId;
  final List<PairedDevice> pairedDevices;
  final String? pairingCode;
  final String? qrCodeData;
  final String? errorText;

  const CrmDeviceState({
    this.isLoading = false,
    this.isPaired = false,
    this.deviceId,
    this.pairedDevices = const [],
    this.pairingCode,
    this.qrCodeData,
    this.errorText,
  });

  CrmDeviceState copyWith({
    bool? isLoading,
    bool? isPaired,
    String? deviceId,
    List<PairedDevice>? pairedDevices,
    String? pairingCode,
    String? qrCodeData,
    String? errorText,
  }) {
    return CrmDeviceState(
      isLoading: isLoading ?? this.isLoading,
      isPaired: isPaired ?? this.isPaired,
      deviceId: deviceId ?? this.deviceId,
      pairedDevices: pairedDevices ?? this.pairedDevices,
      pairingCode: pairingCode ?? this.pairingCode,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      errorText: errorText,
    );
  }
}

CrmDeviceState parseCrmDeviceList(List<dynamic> devices) {
  Map<dynamic, dynamic>? pcDevice;
  Map<dynamic, dynamic>? fallbackActiveDevice;

  for (final device in devices) {
    if (device is! Map || device['status']?.toString() != 'active') {
      continue;
    }
    fallbackActiveDevice ??= device;
    final platform = device['platform']?.toString().toLowerCase() ?? '';
    if (platform.contains('windows')) {
      pcDevice = device;
      break;
    }
  }

  pcDevice ??= fallbackActiveDevice;
  final pairedUsers = _readPairedMobileUsers(pcDevice);
  final pairedDevices = pairedUsers.indexed.map((entry) {
    final index = entry.$1;
    final value = entry.$2;
    final displayName = value is Map
        ? (value['displayName']?.toString() ??
              value['name']?.toString() ??
              value['email']?.toString() ??
              'Thiết bị di động ${index + 1}')
        : 'Thiết bị di động ${index + 1}';
    final platform = value is Map
        ? (value['platform']?.toString() ?? 'Mobile')
        : 'Mobile';

    return PairedDevice(
      id: _readPairedMobileUserId(value, index),
      displayName: displayName,
      platform: platform,
      status: 'active',
    );
  }).toList();

  return CrmDeviceState(
    isPaired: pairedDevices.isNotEmpty,
    deviceId: pcDevice == null
        ? null
        : (pcDevice['_id']?.toString() ?? pcDevice['id']?.toString()),
    pairedDevices: pairedDevices,
  );
}

Map<String, dynamic> buildPairingConfirmPayload(String input) {
  final cleanInput = input.trim();
  final cleanCode = cleanInput.replaceAll(' ', '');
  if (cleanCode.length == 6 && int.tryParse(cleanCode) != null) {
    return {'pairingCode': cleanCode};
  }

  try {
    final decoded = jsonDecode(cleanInput);
    if (decoded is Map) {
      final qrToken =
          decoded['pairingToken']?.toString() ?? decoded['qrToken']?.toString();
      if (qrToken != null && qrToken.isNotEmpty) {
        return {'qrToken': qrToken};
      }
    }
  } catch (_) {
    // Raw QR token fallback.
  }

  return {'qrToken': cleanInput};
}

List<dynamic> _readPairedMobileUsers(Map<dynamic, dynamic>? pcDevice) {
  final value = pcDevice?['pairedMobileUserIds'];
  if (value is List) return value;
  return const [];
}

String _readPairedMobileUserId(dynamic value, int index) {
  if (value is Map) {
    return value['_id']?.toString() ??
        value['id']?.toString() ??
        value['userId']?.toString() ??
        'mobile-$index';
  }
  final id = value?.toString();
  if (id != null && id.isNotEmpty) return id;
  return 'mobile-$index';
}

class CrmDeviceNotifier extends StateNotifier<CrmDeviceState> {
  Timer? _pairingPollTimer;

  CrmDeviceNotifier() : super(const CrmDeviceState()) {
    checkPairingStatus();
  }

  @override
  void dispose() {
    _pairingPollTimer?.cancel();
    super.dispose();
  }

  Future<void> checkPairingStatus() async {
    state = state.copyWith(isLoading: true, errorText: null);
    final response = await CrmCloudApi.get('/crm/devices');

    if (response['success'] == true && response['data'] != null) {
      final parsed = parseCrmDeviceList(List<dynamic>.from(response['data']));
      if (parsed.isPaired) {
        _pairingPollTimer?.cancel();
      }
      state = parsed.copyWith(isLoading: false, errorText: null);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> startPairingProcess() async {
    state = state.copyWith(isLoading: true, errorText: null);

    // 1. Lấy danh sách thiết bị để tìm thiết bị PC máy chủ
    final devicesRes = await CrmCloudApi.get('/crm/devices');
    String? devId;

    if (devicesRes['success'] == true && devicesRes['data'] != null) {
      final parsed = parseCrmDeviceList(List<dynamic>.from(devicesRes['data']));
      devId = parsed.deviceId;
    }

    // 2. Nếu chưa có thiết bị máy chủ, thông báo lỗi cho người dùng
    if (devId == null) {
      state = state.copyWith(
        isLoading: false,
        errorText:
            'Chưa tìm thấy thiết bị máy chủ nào. Vui lòng chạy "npm run crm:register-device" trên máy chủ để đăng ký trước khi ghép đôi.',
      );
      return false;
    }

    // 3. Gọi API bắt đầu ghép đôi với deviceId hợp lệ
    final response = await CrmCloudApi.post('/crm/pairing/start', {
      'deviceId': devId,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      state = state.copyWith(
        isLoading: false,
        deviceId: devId,
        pairingCode: data['pairingCode']?.toString(),
        qrCodeData: jsonEncode({
          'type': 'alpha_crm_pairing',
          'pairingToken':
              data['qrToken']?.toString() ?? data['pairingCode']?.toString(),
        }),
      );
      _startPairingStatusPolling();
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            response['message'] ?? 'Không thể bắt đầu ghép đôi thiết bị.',
      );
      return false;
    }
  }

  Future<bool> confirmPairing(String input) async {
    state = state.copyWith(isLoading: true, errorText: null);
    final response = await CrmCloudApi.post(
      '/crm/pairing/confirm',
      buildPairingConfirmPayload(input),
    );

    if (response['success'] == true) {
      await checkPairingStatus();
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText:
            response['message'] ?? 'Mã ghép đôi không hợp lệ hoặc đã hết hạn.',
      );
      return false;
    }
  }

  void _startPairingStatusPolling() {
    _pairingPollTimer?.cancel();
    _pairingPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || state.isPaired) {
        _pairingPollTimer?.cancel();
        return;
      }
      checkPairingStatus();
    });
  }

  Future<void> unpairDevice([String? targetDeviceId]) async {
    final idToUnpair = targetDeviceId ?? state.deviceId;
    if (idToUnpair == null) {
      state = state.copyWith(
        errorText: 'Không tìm thấy ID thiết bị để hủy ghép đôi.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorText: null);
    final response = await CrmCloudApi.post(
      '/crm/devices/$idToUnpair/disable',
      {},
    );
    if (response['success'] == true) {
      if (idToUnpair == state.deviceId) {
        state = const CrmDeviceState();
      }
      await checkPairingStatus();
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText: response['message'] ?? 'Không thể hủy ghép đôi thiết bị.',
      );
    }
  }
}

final crmDeviceProvider =
    StateNotifierProvider<CrmDeviceNotifier, CrmDeviceState>((ref) {
      return CrmDeviceNotifier();
    });
