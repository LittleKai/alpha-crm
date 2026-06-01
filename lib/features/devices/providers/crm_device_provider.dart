import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/api/crm_cloud_api.dart';

class CrmDeviceState {
  final bool isLoading;
  final bool isPaired;
  final String? deviceId;
  final String? pairedDeviceName;
  final String? pairedDeviceOs;
  final String? pairingCode;
  final String? qrCodeData;
  final String? errorText;

  const CrmDeviceState({
    this.isLoading = false,
    this.isPaired = false,
    this.deviceId,
    this.pairedDeviceName,
    this.pairedDeviceOs,
    this.pairingCode,
    this.qrCodeData,
    this.errorText,
  });

  CrmDeviceState copyWith({
    bool? isLoading,
    bool? isPaired,
    String? deviceId,
    String? pairedDeviceName,
    String? pairedDeviceOs,
    String? pairingCode,
    String? qrCodeData,
    String? errorText,
  }) {
    return CrmDeviceState(
      isLoading: isLoading ?? this.isLoading,
      isPaired: isPaired ?? this.isPaired,
      deviceId: deviceId ?? this.deviceId,
      pairedDeviceName: pairedDeviceName ?? this.pairedDeviceName,
      pairedDeviceOs: pairedDeviceOs ?? this.pairedDeviceOs,
      pairingCode: pairingCode ?? this.pairingCode,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      errorText: errorText,
    );
  }
}

class CrmDeviceNotifier extends StateNotifier<CrmDeviceState> {
  CrmDeviceNotifier() : super(const CrmDeviceState()) {
    checkPairingStatus();
  }

  Future<void> checkPairingStatus() async {
    state = state.copyWith(isLoading: true, errorText: null);
    final response = await CrmCloudApi.get('/crm/devices');
    
    if (response['success'] == true && response['data'] != null) {
      final List<dynamic> list = response['data'];
      final active = list.firstWhere((d) => d['status'] == 'active', orElse: () => null);
      
      if (active != null) {
        state = state.copyWith(
          isLoading: false,
          isPaired: true,
          deviceId: active['_id']?.toString() ?? active['id']?.toString(),
          pairedDeviceName: active['displayName']?.toString() ?? 'Thiết bị liên kết',
          pairedDeviceOs: active['platform']?.toString() ?? 'Windows',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isPaired: false,
          deviceId: null,
        );
      }
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> startPairingProcess() async {
    state = state.copyWith(isLoading: true, errorText: null);
    
    // 1. Lấy danh sách thiết bị để xem đã có thiết bị active chưa
    final devicesRes = await CrmCloudApi.get('/crm/devices');
    String? devId;
    
    if (devicesRes['success'] == true && devicesRes['data'] != null) {
      final List<dynamic> list = devicesRes['data'];
      final active = list.firstWhere((d) => d['status'] == 'active', orElse: () => null);
      if (active != null) {
        devId = active['_id']?.toString() ?? active['id']?.toString();
      }
    }
    
    // 2. Nếu chưa có thiết bị, tự động gọi API đăng ký thiết bị máy chủ
    if (devId == null) {
      final String platform = kIsWeb ? 'web' : 'windows';
      final String finger = 'alpha-crm-fingerprint-${DateTime.now().millisecondsSinceEpoch}';
      
      final registerRes = await CrmCloudApi.post('/crm/devices/register', {
        'machineFingerprint': finger,
        'displayName': kIsWeb ? 'Chrome Web App Host' : 'Windows Desktop Host',
        'platform': platform,
      });
      
      if (registerRes['success'] == true && registerRes['data'] != null) {
        devId = registerRes['data']['deviceId']?.toString();
      } else {
        state = state.copyWith(
          isLoading: false,
          errorText: registerRes['message'] ?? 'Không thể đăng ký thiết bị máy chủ để bắt đầu ghép đôi.',
        );
        return false;
      }
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
        qrCodeData: data['qrToken']?.toString() ?? data['pairingCode']?.toString(),
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText: response['message'] ?? 'Không thể bắt đầu ghép đôi thiết bị.',
      );
      return false;
    }
  }

  Future<bool> confirmPairing(String code) async {
    state = state.copyWith(isLoading: true, errorText: null);
    final response = await CrmCloudApi.post('/crm/pairing/confirm', {
      'pairingCode': code,
    });

    if (response['success'] == true) {
      await checkPairingStatus();
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText: response['message'] ?? 'Mã ghép đôi không hợp lệ hoặc đã hết hạn.',
      );
      return false;
    }
  }

  Future<void> unpairDevice() async {
    if (state.deviceId == null) {
      state = state.copyWith(errorText: 'Không tìm thấy ID thiết bị để hủy ghép đôi.');
      return;
    }

    state = state.copyWith(isLoading: true, errorText: null);
    // Vô hiệu hóa thiết bị hoạt động qua endpoint disable tương ứng của Phase 1
    final response = await CrmCloudApi.post('/crm/devices/${state.deviceId}/disable', {});
    if (response['success'] == true) {
      state = const CrmDeviceState();
      await checkPairingStatus();
    } else {
      state = state.copyWith(
        isLoading: false,
        errorText: response['message'] ?? 'Không thể hủy ghép đôi thiết bị.',
      );
    }
  }
}

final crmDeviceProvider = StateNotifierProvider<CrmDeviceNotifier, CrmDeviceState>((ref) {
  return CrmDeviceNotifier();
});
