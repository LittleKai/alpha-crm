import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/zalo_backend_manager.dart';

/// Dải trạng thái mỏng ở đỉnh app, phản ánh vòng đời backend Zalo cục bộ.
///
/// Khi backend khỏe (hoặc đã dừng có chủ đích) thì ẩn hoàn toàn (không chiếm
/// layout). Khi đang khởi động/gián đoạn/thất bại thì hiện thông báo rõ ràng;
/// trạng thái thất bại kèm nút "Thử lại" gọi [ZaloBackendManager.retryManually].
class BackendStatusBanner extends StatelessWidget {
  const BackendStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BackendStatus>(
      valueListenable: ZaloBackendManager.status,
      builder: (context, status, _) {
        final info = _infoFor(status);
        if (info == null) return const SizedBox.shrink();

        return Material(
          color: info.background,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  if (info.showSpinner)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Icon(info.icon, size: 16, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      info.message,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (info.showRetry) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => ZaloBackendManager.retryManually(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Thử lại',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  _BannerInfo? _infoFor(BackendStatus status) {
    switch (status) {
      case BackendStatus.healthy:
      case BackendStatus.stopped:
        return null;
      case BackendStatus.starting:
        return const _BannerInfo(
          message: 'Đang khởi động dịch vụ Zalo cục bộ...',
          background: Color(0xFF2563EB),
          icon: Icons.sync,
          showSpinner: true,
        );
      case BackendStatus.restarting:
        return const _BannerInfo(
          message: 'Dịch vụ Zalo đã dừng — đang tự khởi động lại...',
          background: Color(0xFFD97706),
          icon: Icons.restart_alt,
          showSpinner: true,
        );
      case BackendStatus.degraded:
        return const _BannerInfo(
          message: 'Dịch vụ Zalo đang gián đoạn, đang kiểm tra lại...',
          background: Color(0xFFD97706),
          icon: Icons.warning_amber_rounded,
        );
      case BackendStatus.failed:
        return const _BannerInfo(
          message:
              'Không thể khởi động dịch vụ Zalo cục bộ sau nhiều lần thử.',
          background: Color(0xFFDC2626),
          icon: Icons.error_outline,
          showRetry: true,
        );
    }
  }
}

class _BannerInfo {
  final String message;
  final Color background;
  final IconData icon;
  final bool showSpinner;
  final bool showRetry;

  const _BannerInfo({
    required this.message,
    required this.background,
    required this.icon,
    this.showSpinner = false,
    this.showRetry = false,
  });
}
