import 'package:flutter/material.dart';
import '../utils/desktop_window_manager.dart';
import 'app_dialog.dart';
import 'app_button.dart';

/// Bọc toàn app: khi user nhấn nút X (Windows), `DesktopShell.closeRequest` bật
/// và widget này hiện dialog xác nhận 3 lựa chọn:
/// Thoát luôn / Ẩn xuống tray / Hủy.
///
/// Render dialog trực tiếp trong cây widget (không qua `showDialog`) để không
/// phụ thuộc Navigator của GoRouter — hoạt động ở mọi màn hình (kể cả login).
class AppCloseGate extends StatelessWidget {
  final Widget child;

  const AppCloseGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DesktopShell.closeRequest,
      builder: (context, requested, _) {
        return Stack(
          children: [
            child,
            if (requested)
              Positioned.fill(
                child: Stack(
                  children: [
                    // Lớp nền mờ — chạm ra ngoài = Hủy.
                    GestureDetector(
                      onTap: () => DesktopShell.instance.cancelClose(),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                    Center(
                      child: AppDialog(
                        title: 'Đóng ứng dụng',
                        icon: Icons.power_settings_new_rounded,
                        showCloseButton: false,
                        width: 480,
                        subtitle:
                            'Bạn muốn thoát hẳn ứng dụng hay thu nhỏ xuống '
                            'khay hệ thống (System Tray) để chạy nền?',
                        actions: [
                          AppDialogAction(
                            text: 'Hủy',
                            variant: AppButtonVariant.outline,
                            onPressed: () =>
                                DesktopShell.instance.cancelClose(),
                          ),
                          AppDialogAction(
                            text: 'Ẩn xuống tray',
                            icon: Icons.minimize_rounded,
                            variant: AppButtonVariant.primary,
                            onPressed: () => DesktopShell.instance.hideToTray(),
                          ),
                          AppDialogAction(
                            text: 'Thoát luôn',
                            icon: Icons.power_settings_new_rounded,
                            variant: AppButtonVariant.destructive,
                            onPressed: () => DesktopShell.instance.exitApp(),
                          ),
                        ],
                        child: const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
