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

class CrmDeviceNotifier extends StateNotifier<CrmDeviceState> {
  CrmDeviceNotifier() : super(const CrmDeviceState()) {
    checkPairingStatus();
  }

  Future<void> checkPairingStatus() async {
    state = state.copyWith(isLoading: true, errorText: null);
    final response = await CrmCloudApi.get('/crm/devices');

    if (response['success'] == true && response['data'] != null) {
      final List<dynamic> list = response['data'];
      
      // Tìm thiết bị PC hiện tại (active và platform là Windows)
      final pcDevice = list.firstWhere(
        (d) => d['platform']?.toString().toLowerCase().contains('windows') == true && d['status'] == 'active',
        orElse: () => list.firstWhere(
          (d) => d['status'] == 'active',
          orElse: () => null,
        ),
      );

      // Tìm tất cả các thiết bị di động đã ghép đôi hoạt động (active và platform không phải Windows)
      final List<PairedDevice> mobileDevices = list
          .where((d) =>
              d['platform']?.toString().toLowerCase().contains('windows') != true &&
              d['status'] == 'active')
          .map((d) => PairedDevice(
                id: d['_id']?.toString() ?? d['id']?.toString() ?? '',
                displayName: d['displayName']?.toString() ?? 'Thiết bị di động',
                platform: d['platform']?.toString() ?? 'Android',
                status: d['status']?.toString() ?? 'active',
              ))
          .toList();

      state = state.copyWith(
        isLoading: false,
        isPaired: mobileDevices.isNotEmpty,
        deviceId: pcDevice != null ? (pcDevice['_id']?.toString() ?? pcDevice['id']?.toString()) : null,
        pairedDevices: mobileDevices,
      );
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
      final List<dynamic> list = devicesRes['data'];
      final pcDevice = list.firstWhere(
        (d) => d['platform']?.toString().toLowerCase().contains('windows') == true && d['status'] == 'active',
        orElse: () => list.firstWhere(
          (d) => d['status'] == 'active',
          orElse: () => null,
        ),
      );
      if (pcDevice != null) {
        devId = pcDevice['_id']?.toString() ?? pcDevice['id']?.toString();
      }
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
        qrCodeData:
            data['qrToken']?.toString() ?? data['pairingCode']?.toString(),
      );
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
        errorText:
            response['message'] ?? 'Mã ghép đôi không hợp lệ hoặc đã hết hạn.',
      );
      return false;
    }
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
