import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'zalo_backend_manager.dart';

/// Quản lý cửa sổ + System Tray cho Windows desktop.
///
/// - Mở app: luôn phóng to hết cỡ (maximized — do native runner xử lý).
/// - Nhấn nút X: KHÔNG thoát/ẩn ngay, mà bật [closeRequest] để UI hiện dialog
///   xác nhận 3 lựa chọn (Thoát luôn / Ẩn xuống tray / Hủy).
/// - Tray: nhấp trái → hiện lại; nhấp phải → menu (Hiện ứng dụng / Thoát).
/// - "Thoát" mới thực sự kết thúc app (tắt backend trước).
class DesktopShell with WindowListener, TrayListener {
  static final DesktopShell instance = DesktopShell._();
  DesktopShell._();

  static const String _trayIconPath = 'assets/app_icon.ico';
  static const String _menuKeyShow = 'show';
  static const String _menuKeyExit = 'exit';

  /// Bật lên true khi user nhấn nút X → tầng UI (`AppCloseGate`) hiện dialog
  /// xác nhận. UI gọi lại [exitApp]/[hideToTray]/[cancelClose] theo lựa chọn.
  static final ValueNotifier<bool> closeRequest = ValueNotifier<bool>(false);

  bool get _supported => Platform.isWindows;
  bool _isExiting = false;

  Future<void> init() async {
    if (!_supported) return;

    await windowManager.ensureInitialized();

    // Chặn nút X để tự xử lý (hiện dialog xác nhận).
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    await _setupTray();
    trayManager.addListener(this);

    // Maximize: native runner đã ShowWindow(SW_SHOWMAXIMIZED), nhưng window_manager
    // có thể đặt lại cửa sổ về size mặc định trong lúc init → "phóng to rồi thu
    // nhỏ". Tái khẳng định maximize sau khi init ổn định; nếu đã maximized sẵn thì
    // bỏ qua (không nháy).
    _reassertMaximized();
  }

  /// Bảo đảm cửa sổ ở trạng thái maximized, thử vài nhịp để override mọi lần
  /// window_manager thu nhỏ muộn lúc khởi động.
  Future<void> _reassertMaximized() async {
    if (!_supported) return;
    for (final delayMs in [300, 800, 1500]) {
      await Future.delayed(Duration(milliseconds: delayMs));
      try {
        if (!await windowManager.isMaximized()) {
          await windowManager.maximize();
        }
      } catch (_) {
        /* ignore */
      }
    }
  }

  Future<void> _setupTray() async {
    await trayManager.setIcon(_trayIconPath);
    try {
      await trayManager.setToolTip('Alpha CRM');
    } catch (_) {
      // setToolTip không bắt buộc trên mọi nền tảng.
    }
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: _menuKeyShow, label: 'Hiện ứng dụng'),
          MenuItem.separator(),
          MenuItem(key: _menuKeyExit, label: 'Thoát'),
        ],
      ),
    );
  }

  // --- WindowListener ---

  @override
  void onWindowClose() {
    if (_isExiting) return;
    // Nút X → yêu cầu UI hiện dialog xác nhận (không tự thoát/ẩn).
    closeRequest.value = true;
  }

  /// Ẩn cửa sổ xuống System Tray (lựa chọn "Ẩn xuống tray").
  Future<void> hideToTray() async {
    closeRequest.value = false;
    if (_supported) {
      await windowManager.hide();
    }
  }

  /// Bỏ qua yêu cầu đóng (lựa chọn "Hủy").
  void cancelClose() {
    closeRequest.value = false;
  }

  // --- TrayListener ---

  @override
  void onTrayIconMouseDown() {
    unawaited(_restoreWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _menuKeyShow:
        unawaited(_restoreWindow());
        break;
      case _menuKeyExit:
        unawaited(exitApp());
        break;
    }
  }

  Future<void> _restoreWindow() async {
    if (!await windowManager.isVisible()) {
      await windowManager.show();
    }
    await windowManager.focus();
  }

  /// Thoát hẳn ứng dụng (lựa chọn "Thoát luôn" / menu tray "Thoát").
  Future<void> exitApp() async {
    _isExiting = true;
    closeRequest.value = false;
    // Xin backend tắt sạch (đóng SQLite + checkpoint WAL) trước, có deadline;
    // hết hạn thì tự rơi xuống kill nên không treo được cửa sổ.
    await ZaloBackendManager.shutdownGracefully();
    // Dọn icon tray, có timeout để không treo nếu plugin phản hồi chậm.
    try {
      await trayManager.destroy().timeout(const Duration(seconds: 2));
    } catch (_) {
      /* ignore */
    }
    // Thoát DỨT KHOÁT — không chờ teardown của Flutter/window_manager (đây là
    // nguồn gây treo). Tiến trình app kết thúc → Windows Job Object diệt backend.
    exit(0);
  }
}
