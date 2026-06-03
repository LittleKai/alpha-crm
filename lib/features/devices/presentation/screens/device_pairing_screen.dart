import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../providers/crm_device_provider.dart';

class DevicePairingScreen extends ConsumerStatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  ConsumerState<DevicePairingScreen> createState() =>
      _DevicePairingScreenState();
}

class _DevicePairingScreenState extends ConsumerState<DevicePairingScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitPairingCode() async {
    if (!_formKey.currentState!.validate()) return;

    final cleanCode = _codeController.text.replaceAll(' ', '').trim();
    final success = await ref
        .read(crmDeviceProvider.notifier)
        .confirmPairing(cleanCode);

    if (success && mounted) {
      _codeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ghép đôi thiết bị thành công!'),
          backgroundColor: AppColors.successText,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(crmDeviceProvider);
    final isClient = kIsWeb || defaultTargetPlatform == TargetPlatform.android;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ghép Đôi Thiết Bị',
          style: AppTextStyles.pageTitle.copyWith(fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon & Header
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: deviceState.isPaired
                              ? AppColors.successSoft
                              : AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          deviceState.isPaired
                              ? Icons.phonelink_ring_rounded
                              : Icons.sensors_rounded,
                          color: deviceState.isPaired
                              ? AppColors.success
                              : AppColors.primary,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      deviceState.isPaired
                          ? 'Thiết Bị Đã Được Ghép Đôi'
                          : 'Yêu Cầu Ghép Đôi Thiết Bị',
                      style: AppTextStyles.sectionTitle.copyWith(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      deviceState.isPaired
                          ? 'Tài khoản của bạn đã được liên kết với một thiết bị. Hệ thống đã sẵn sàng điều phối lệnh chiến dịch.'
                          : 'Để đồng bộ dữ liệu Zalo cá nhân từ máy tính sang điện thoại di động hoặc web, bạn cần ghép đôi thiết bị.',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    if (deviceState.errorText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          deviceState.errorText!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.errorText,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (deviceState.isPaired) ...[
                      _buildPairedState(deviceState),
                    ] else ...[
                      if (isClient) ...[
                        _buildAndroidPairingInput(deviceState),
                      ] else ...[
                        _buildWindowsHostPairing(deviceState),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPairedState(CrmDeviceState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                'Tên thiết bị liên kết:',
                state.pairedDeviceName ?? 'Không rõ',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                'Hệ điều hành:',
                state.pairedDeviceOs ?? 'Không rõ',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                'Trạng thái kết nối:',
                'Sẵn sàng hoạt động',
                isStatus: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: state.isLoading
              ? null
              : () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Hủy Ghép Đôi Thiết Bị'),
                      content: const Text(
                        'Cảnh báo: Nếu hủy ghép đôi thiết bị này, bạn sẽ không thể đồng bộ chiến dịch tự động qua Zalo cá nhân được nữa cho đến khi thực hiện ghép đôi lại.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Đóng'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ref.read(crmDeviceProvider.notifier).unpairDevice();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                          ),
                          child: const Text('Xác Nhận Hủy'),
                        ),
                      ],
                    ),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.errorSoft,
            foregroundColor: AppColors.errorText,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: state.isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.errorText,
                  ),
                )
              : const Text('Hủy Ghép Đôi Thiết Bị Hiện Tại'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        if (isStatus)
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.successText,
                  fontSize: 13,
                ),
              ),
            ],
          )
        else
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
      ],
    );
  }

  Widget _buildAndroidPairingInput(CrmDeviceState state) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nhập Mã Ghép Đôi 6 Chữ Số',
            style: AppTextStyles.label,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              hintText: '123 456',
              hintStyle: TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                color: Colors.grey,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng điền mã ghép đôi.';
              }
              final clean = value.replaceAll(' ', '');
              if (clean.length != 6 || int.tryParse(clean) == null) {
                return 'Mã ghép đôi phải gồm đúng 6 chữ số.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: state.isLoading ? null : _submitPairingCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: state.isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Xác Nhận Kết Nối'),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.amberSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'ℹ️ Hướng dẫn: Mở ứng dụng Alpha CRM trên máy tính Windows đã cài đặt Zalo cá nhân, điều hướng tới phần Thiết bị để tạo mã code 6 số này.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.warningText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowsHostPairing(CrmDeviceState state) {
    final showCode = state.pairingCode != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!showCode) ...[
          Text(
            'Hệ thống đang chạy trên Windows / Web Client.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: state.isLoading
                ? null
                : () => ref
                      .read(crmDeviceProvider.notifier)
                      .startPairingProcess(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: state.isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Bắt Đầu Quy Trình Ghép Đôi'),
          ),
        ] else ...[
          // Hiển thị code 6 số và QR mock
          Center(
            child: Column(
              children: [
                Text(
                  'MÃ GHÉP ĐÔI CỦA BẠN',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.slateSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${state.pairingCode!.substring(0, 3)} ${state.pairingCode!.substring(3, 6)}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Mock QR Code
                Container(
                  width: 180,
                  height: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Styled Custom QR block grid representation using icons and squares
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          4,
                          (index) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              4,
                              (subIndex) => Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: (index + subIndex) % 2 == 0
                                      ? AppColors.textPrimary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.rocket_launch_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Quét mã QR hoặc nhập mã code 6 số bên trên từ ứng dụng di động Android để liên kết thiết bị lập tức.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: state.isLoading
                ? null
                : () => ref
                      .read(crmDeviceProvider.notifier)
                      .startPairingProcess(),
            child: const Text('Tạo lại mã ghép đôi mới'),
          ),
        ],
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.errorSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '⚠️ Cảnh báo giấy phép: Tài khoản Alpha CRM chỉ hỗ trợ ghép đôi liên kết 1 máy tính Windows tại một thời điểm để đảm bảo tính an toàn dữ liệu.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.errorText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
