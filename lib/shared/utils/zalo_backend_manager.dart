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
      debugPrint(
        "ZaloBackendManager: Chạy trên Web/Mobile, tự động bỏ qua tự chạy backend.",
      );
      return false;
    }

    if (_isRunning) {
      debugPrint("ZaloBackendManager: Backend đã đang chạy.");
      return true;
    }

    try {
      // 2. Xác định launcher backend tương ứng với hệ điều hành
      final candidateNames = Platform.isWindows
          ? const [
              'zalo-bot-service.cmd',
              'zalo-bot-service.exe',
              'zalo-bot-service.bat',
            ]
          : const ['zalo-bot-service'];

      // 3. Ưu tiên thư mục chứa app Flutter, fallback về working directory khi debug
      final appDir = File(Platform.resolvedExecutable).parent.path;
      final currentDir = Directory.current.path;
      final searchDirs = appDir == currentDir ? [appDir] : [appDir, currentDir];

      String? executablePath;
      for (final dir in searchDirs) {
        for (final candidateName in candidateNames) {
          final candidatePath = '$dir${Platform.pathSeparator}$candidateName';
          if (await File(candidatePath).exists()) {
            executablePath = candidatePath;
            break;
          }
        }
        if (executablePath != null) break;
      }

      // 4. Kiểm tra launcher backend có tồn tại không
      if (executablePath == null) {
        if (kDebugMode) {
          debugPrint(
            "ZaloBackendManager (Development): Không tìm thấy launcher backend (${candidateNames.join(', ')}). "
            "Điều này là bình thường trong môi trường phát triển (debug). Bạn hãy chạy backend bằng lệnh 'npm run dev' "
            "trong thư mục 'integration/zalo-bot-service' để phát triển.",
          );
        } else {
          debugPrint(
            "ZaloBackendManager (Production): Không tìm thấy launcher backend (${candidateNames.join(', ')}). Vui lòng kiểm tra file đóng gói.",
          );
        }
        return false;
      }

      debugPrint(
        "ZaloBackendManager: Đang khởi động backend tại: $executablePath",
      );

      // 5. Khởi động tiến trình chạy ngầm không hiển thị cửa sổ console đen (ẩn danh)
      _backendProcess = await Process.start(
        executablePath,
        [],
        runInShell: true,
        mode:
            ProcessStartMode.normal, // Chạy ẩn danh không hiển thị terminal đen
        workingDirectory: File(executablePath).parent.path,
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
      debugPrint(
        "ZaloBackendManager: Đang ngắt tiến trình chạy ngầm backend...",
      );
      _backendProcess!.kill();
      _backendProcess = null;
      _isRunning = false;
      debugPrint("ZaloBackendManager: Đã ngắt tiến trình backend hoàn toàn.");
    }
  }
}
