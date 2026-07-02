import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../app/routing/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../messaging/live_chat/providers/live_chat_provider.dart';
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
      final isClient = kIsWeb || defaultTargetPlatform == TargetPlatform.android;
      if (isClient) {
        // Newly paired mobile/web client: refresh the Zalo account list so
        // Live Chat has something to show immediately (FE-6).
        unawaited(ref.read(liveChatProvider.notifier).loadAccounts());
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ghép đôi thiết bị thành công!'),
          backgroundColor: AppColors.successText,
          action: isClient
              ? SnackBarAction(
                  label: 'Mở Live Chat',
                  textColor: Colors.white,
                  onPressed: () {
                    if (mounted) context.go(AppRoutes.messagingLiveChat);
                  },
                )
              : null,
        ),
      );
    }
  }

  Future<void> _confirmUnpairDevice(PairedDevice dev) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Ngắt kết nối Remote',
        icon: Icons.link_off_rounded,
        actions: [
          AppDialogAction(
            text: 'Bỏ qua',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppDialogAction(
            text: 'Xác Nhận Hủy',
            variant: AppButtonVariant.destructive,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
        child: Text(
          'Bạn có chắc chắn muốn hủy ghép đôi thiết bị "${dev.displayName}" không? Điện thoại này sẽ không thể đồng bộ chiến dịch tự động qua PC này nữa.',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(crmDeviceProvider.notifier).revokePairedMobile(dev.id);
    }
  }

  void _openQrScanner() {
    var didScan = false;
    showDialog(
      context: context,
      builder: (context) {
        return AppDialog(
          title: 'Quét QR từ màn hình PC',
          icon: Icons.qr_code_scanner_rounded,
          width: 420,
          actions: [
            AppDialogAction(
              text: 'Hủy',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.pop(context),
            ),
          ],
          child: SizedBox(
            width: 360,
            height: 360,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MobileScanner(
                onDetect: (capture) {
                  if (didScan) return;
                  final value = capture.barcodes
                      .map((barcode) => barcode.rawValue)
                      .whereType<String>()
                      .firstWhere(
                        (rawValue) => rawValue.trim().isNotEmpty,
                        orElse: () => '',
                      );
                  if (value.isEmpty) return;
                  didScan = true;
                  Navigator.pop(context);
                  _codeController.text = value;
                  _submitPairingCode();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void simulateQrScanner() {
    showDialog(
      context: context,
      builder: (context) {
        final tokenController = TextEditingController();
        return AppDialog(
          title: 'Mô phỏng Quét QR Code',
          icon: Icons.qr_code_rounded,
          width: 500,
          actions: [
            AppDialogAction(
              text: 'Hủy',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.pop(context),
            ),
            AppDialogAction(
              text: 'Xác nhận quét',
              onPressed: () {
                final input = tokenController.text.trim();
                Navigator.pop(context);
                if (input.isNotEmpty) {
                  _codeController.text = input;
                  _submitPairingCode();
                }
              },
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Trên điện thoại thật, camera sẽ mở để quét mã QR trên PC. \n\nĐể thử nghiệm, bạn hãy nhập mã ghép đôi (6 chữ số) hoặc paste chuỗi token ghép đôi từ PC vào đây:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tokenController,
                decoration: const InputDecoration(
                  labelText: 'Mã hoặc Token ghép đôi',
                  hintText: 'Ví dụ: 123456',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(crmDeviceProvider);
    final isClient = kIsWeb || defaultTargetPlatform == TargetPlatform.android;

    final bool showPairedState = isClient
        ? deviceState.isPaired
        : deviceState.pairedDevices.isNotEmpty;

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
                          color: showPairedState
                              ? AppColors.successSoft
                              : AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          showPairedState
                              ? Icons.phonelink_ring_rounded
                              : Icons.sensors_rounded,
                          color: showPairedState
                              ? AppColors.success
                              : AppColors.primary,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isClient
                          ? (deviceState.isPaired
                                ? 'Thiết Bị Đã Được Ghép Đôi'
                                : 'Yêu Cầu Ghép Đôi Thiết Bị')
                          : (deviceState.pairedDevices.isNotEmpty
                                ? 'Thiết Bị Di Động Đã Kết Nối'
                                : 'Chưa Có Thiết Bị Di Động Kết Nối'),
                      style: AppTextStyles.sectionTitle.copyWith(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isClient
                          ? (deviceState.isPaired
                                ? 'Thiết bị di động của bạn đã liên kết thành công với máy chủ PC.'
                                : 'Để đồng bộ dữ liệu Zalo cá nhân từ máy tính sang điện thoại di động, bạn cần ghép đôi thiết bị.')
                          : (deviceState.pairedDevices.isNotEmpty
                                ? 'Danh sách các thiết bị di động đang đồng bộ dữ liệu chiến dịch và Live Chat qua máy chủ này (Tối đa 3 thiết bị).'
                                : 'Vui lòng sử dụng điện thoại di động quét mã QR hoặc nhập mã code bên dưới để liên kết thiết bị.'),
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
                            color: AppColors.error.withValues(alpha: 0.3),
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

                    if (isClient) ...[
                      // Giao diện trên điện thoại di động
                      if (deviceState.isPaired) ...[
                        _buildPairedState(deviceState),
                      ] else ...[
                        _buildAndroidPairingInput(deviceState),
                      ],
                    ] else ...[
                      // Giao diện trên máy tính Windows
                      if (deviceState.pairedDevices.isNotEmpty) ...[
                        _buildPairedState(deviceState),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 24),
                      ],
                      if (deviceState.pairedDevices.length < 3) ...[
                        _buildWindowsHostPairing(deviceState),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.amberSoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.warningText,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Đã kết nối đủ số lượng tối đa 3 thiết bị di động. Vui lòng hủy ghép đôi thiết bị cũ trước khi liên kết thêm thiết bị mới.',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.warningText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
    final isClient = kIsWeb || defaultTargetPlatform == TargetPlatform.android;

    if (isClient) {
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
                  'Thiết bị di động của bạn:',
                  'Đã liên kết thành công',
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
                      builder: (context) => AppDialog(
                        title: 'Ngắt kết nối Remote',
                        icon: Icons.warning_amber_rounded,
                        actions: [
                          AppDialogAction(
                            text: 'Đóng',
                            variant: AppButtonVariant.outline,
                            onPressed: () => Navigator.pop(context),
                          ),
                          AppDialogAction(
                            text: 'Xác Nhận Hủy',
                            variant: AppButtonVariant.destructive,
                            onPressed: () {
                              Navigator.pop(context);
                              ref
                                  .read(crmDeviceProvider.notifier)
                                  .disconnectCurrentMobileRemote();
                            },
                          ),
                        ],
                        child: const Text(
                          'Cảnh báo: Nếu hủy ghép đôi thiết bị này, bạn sẽ không thể đồng bộ dữ liệu chiến dịch tự động qua Zalo cá nhân được nữa.',
                        ),
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
                ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.errorText,
                    ),
                  )
                : const Text('Ngắt kết nối Remote'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'THIẾT BỊ DI ĐỘNG ĐANG LIÊN KẾT (${state.pairedDevices.length}/3)',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.pairedDevices.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final dev = state.pairedDevices[index];
            final devIcon =
                dev.platform.toLowerCase().contains('ios') ||
                    dev.platform.toLowerCase().contains('apple')
                ? Icons.phone_iphone_rounded
                : Icons.phone_android_rounded;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(devIcon, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dev.displayName,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Đang kết nối (${dev.platform})',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.successText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ngắt kết nối Remote này',
                    icon: const Icon(
                      Icons.link_off_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    onPressed: state.isLoading
                        ? null
                        : () => _confirmUnpairDevice(dev),
                  ),
                ],
              ),
            );
          },
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
              if (clean.length == 6 && int.tryParse(clean) != null) {
                return null;
              }
              if (value.trim().startsWith('{') || value.trim().length >= 16) {
                return null;
              }
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
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: state.isLoading
                ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnPrimary,
                    ),
                  )
                : const Text('Xác Nhận Kết Nối'),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'HOẶC',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _openQrScanner(),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Quét mã QR từ màn hình PC'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: state.isLoading
                ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnPrimary,
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
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // QR Code
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
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: state.qrCodeData ?? state.pairingCode!,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                    eyeStyle: QrEyeStyle(color: AppColors.textPrimary),
                    dataModuleStyle: QrDataModuleStyle(
                      color: AppColors.textPrimary,
                    ),
                    padding: EdgeInsets.zero,
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
