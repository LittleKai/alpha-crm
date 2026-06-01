import 'dart:io';
import 'package:flutter/foundation.dart';

/// Quản lý tiến trình chạy ngầm Node.js Zalo Bot Service trên môi trường Desktop
class ZaloBackendManager {
  static Process? _backendProcess;
  static bool _isRunning = false;

  /// Khởi động tiến trình chạy ngầm Zalo Bot Service
  static Future<bool> startBackend() async {
    // 1. Chỉ thực thi trên môi trường Desktop (Windows, macOS, Linux)
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      debugPrint("ZaloBackendManager: Chạy trên Web/Mobile, tự động bỏ qua tự chạy backend.");
      return false;
    }

    if (_isRunning) {
      debugPrint("ZaloBackendManager: Backend đã đang chạy.");
      return true;
    }

    try {
      // 2. Xác định tên file thực thi tương ứng với hệ điều hành
      String binaryName = 'zalo-bot-service';
      if (Platform.isWindows) {
        binaryName = 'zalo-bot-service.exe';
      }

      // 3. Lấy đường dẫn thư mục hiện tại chứa app Flutter
      String currentDir = Directory.current.path;
      String exePath = '$currentDir/$binaryName';

      // 4. Kiểm tra file chạy có tồn tại không
      if (!await File(exePath).exists()) {
        if (kDebugMode) {
          debugPrint("ZaloBackendManager (Development): Không tìm thấy file chạy zalo-bot-service.exe tại $exePath. "
              "Điều này là bình thường trong môi trường phát triển (debug). Bạn hãy chạy backend bằng lệnh 'npm run dev' "
              "trong thư mục 'integration/zalo-bot-service' để phát triển.");
        } else {
          debugPrint("ZaloBackendManager (Production): Không tìm thấy file chạy tại $exePath. Vui lòng kiểm tra file đóng gói.");
        }
        return false;
      }

      debugPrint("ZaloBackendManager: Đang khởi động backend tại: $exePath");

      // 5. Khởi động tiến trình chạy ngầm không hiển thị cửa sổ console đen (ẩn danh)
      _backendProcess = await Process.start(
        exePath,
        [],
        runInShell: true,
        mode: ProcessStartMode.normal, // Chạy ẩn danh không hiển thị terminal đen
      );

      _isRunning = true;
      debugPrint("ZaloBackendManager: Backend đã khởi động thành công.");

      // Lắng nghe dữ liệu đầu ra từ backend để tiện debug trong quá trình phát triển
      _backendProcess!.stdout.listen((data) {
        if (kDebugMode) {
          debugPrint("ZaloBot-Log: ${String.fromCharCodes(data).trim()}");
        }
      });

      _backendProcess!.stderr.listen((data) {
        debugPrint("ZaloBot-Error-Log: ${String.fromCharCodes(data).trim()}");
      });

      return true;
    } catch (e) {
      debugPrint("ZaloBackendManager: Lỗi khi chạy backend: $e");
      _isRunning = false;
      return false;
    }
  }

  /// Tắt tiến trình chạy ngầm khi đóng ứng dụng
  static void stopBackend() {
    if (_backendProcess != null && _isRunning) {
      debugPrint("ZaloBackendManager: Đang ngắt tiến trình chạy ngầm backend...");
      _backendProcess!.kill();
      _backendProcess = null;
      _isRunning = false;
      debugPrint("ZaloBackendManager: Đã ngắt tiến trình backend hoàn toàn.");
    }
  }
}
