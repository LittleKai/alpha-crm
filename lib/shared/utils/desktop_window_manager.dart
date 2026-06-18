import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'zalo_backend_manager.dart';

/// Quản lý cửa sổ + System Tray cho Windows desktop.
///
/// - Mở app: luôn phóng to hết cỡ (maximized).
/// - Nhấn nút X: KHÔNG thoát, mà ẩn cửa sổ xuống System Tray.
/// - Tray: nhấp trái → hiện lại; nhấp phải → menu (Hiện ứng dụng / Thoát).
/// - "Thoát" mới thực sự kết thúc app (tắt backend trước).
class DesktopShell with WindowListener, TrayListener {
  static final DesktopShell instance = DesktopShell._();
  DesktopShell._();

  static const String _trayIconPath = 'assets/app_icon.ico';
  static const String _menuKeyShow = 'show';
  static const String _menuKeyExit = 'exit';

  bool get _supported => !kIsWeb && Platform.isWindows;
  bool _isExiting = false;

  Future<void> init() async {
    if (!_supported) return;

    await windowManager.ensureInitialized();

    // Maximize do native runner xử lý (windows/runner/main.cpp:
    // ShowWindow(SW_SHOWMAXIMIZED)). KHÔNG gọi maximize()/show() từ Dart ở đây —
    // window_manager show() lại đặt cửa sổ về size mặc định, gây hiện tượng
    // "maximize rồi thu nhỏ" ngay khi khởi động.

    // Chặn nút X để tự xử lý (ẩn xuống tray).
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    await _setupTray();
    trayManager.addListener(this);
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
  void onWindowClose() async {
    if (_isExiting) return;
    // Nút X → ẩn xuống tray thay vì thoát.
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
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
        unawaited(_exitApp());
        break;
    }
  }

  Future<void> _restoreWindow() async {
    if (!await windowManager.isVisible()) {
      await windowManager.show();
    }
    await windowManager.focus();
  }

  Future<void> _exitApp() async {
    _isExiting = true;
    ZaloBackendManager.stopBackend(); // tắt backend trước khi thoát hẳn
    try {
      await trayManager.destroy();
    } catch (_) {
      /* ignore */
    }
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
