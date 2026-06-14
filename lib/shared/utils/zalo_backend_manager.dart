import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Quản lý tiến trình chạy ngầm Node.js Zalo Bot Service trên môi trường Desktop
class ZaloBackendManager {
  static Process? _backendProcess;
  static bool _isRunning = false;
  static int? _activePort;

  /// Cổng đang hoạt động của backend (null nếu chưa dò được)
  static int? get activePort => _activePort;

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
            "Dò tìm file active-port.json để đồng bộ cổng tự động...",
          );
          final portFile = _getActivePortFile(null);
          if (await portFile.exists()) {
            try {
              final content = await portFile.readAsString();
              final data = jsonDecode(content);
              if (data is Map && data['port'] is int) {
                final activePort = data['port'] as int;
                debugPrint(
                  "ZaloBackendManager (Development): Phát hiện cổng active manually: $activePort",
                );
                _activePort = activePort;
                await _updateSettingsPort(activePort);
              }
            } catch (e) {
              debugPrint(
                "ZaloBackendManager (Development): Lỗi đọc active-port.json: $e",
              );
            }
          }
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
      debugPrint(
        "ZaloBackendManager: Backend đã khởi động thành công. Đang dò tìm cổng active...",
      );

      // Dò tìm cổng active từ file port sinh ra bởi Node.js backend
      final portFile = _getActivePortFile(executablePath);

      for (int i = 0; i < 25; i++) {
        // Chờ tối đa 5 giây (25 * 200ms)
        if (await portFile.exists()) {
          try {
            final content = await portFile.readAsString();
            final data = jsonDecode(content);
            if (data is Map && data['port'] is int) {
              _activePort = data['port'] as int;
              break;
            }
          } catch (_) {
            // Đang ghi dở, đợi vòng lặp kế tiếp
          }
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (_activePort != null) {
        debugPrint(
          "ZaloBackendManager: Phát hiện cổng active của Backend: $_activePort",
        );
        await _updateSettingsPort(_activePort!);
      } else {
        debugPrint(
          "ZaloBackendManager: Không tìm thấy cổng active của Backend. Sử dụng cổng mặc định.",
        );
      }

      // Lắng nghe dữ liệu đầu ra từ backend để tiện debug trong quá trình phát triển
      _backendProcess!.stdout.listen((data) {
        debugPrint("ZaloBot-Log: ${String.fromCharCodes(data).trim()}");
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

  /// Chờ cho đến khi backend sẵn sàng phục vụ request (poll GET /health).
  /// Trả về true nếu backend healthy, false nếu hết thời gian chờ.
  /// [timeout] tổng thời gian chờ tối đa, mặc định 20 giây.
  static Future<bool> waitUntilReady({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      return false;
    }

    final port = _activePort ?? 8787;
    final healthUrl = Uri.parse('http://127.0.0.1:$port/health');
    final deadline = DateTime.now().add(timeout);
    final client = http.Client();

    debugPrint(
      'ZaloBackendManager: Đang chờ backend sẵn sàng tại $healthUrl...',
    );

    try {
      while (DateTime.now().isBefore(deadline)) {
        try {
          final response = await client
              .get(healthUrl)
              .timeout(const Duration(seconds: 3));
          if (response.statusCode == 200) {
            final body = jsonDecode(response.body);
            if (body is Map && body['status'] == 'ok') {
              debugPrint(
                'ZaloBackendManager: Backend đã sẵn sàng! (status: ok)',
              );
              return true;
            }
          }
        } catch (_) {
          // Backend chưa sẵn sàng, tiếp tục poll
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      client.close();
    }

    debugPrint(
      'ZaloBackendManager: Hết thời gian chờ backend sẵn sàng (${timeout.inSeconds}s).',
    );
    return false;
  }

  /// Xác định file lưu trữ cổng của Backend
  static File _getActivePortFile(String? executablePath) {
    if (executablePath != null) {
      final workingDir = File(executablePath).parent.path;
      return File(
        '$workingDir${Platform.pathSeparator}.data${Platform.pathSeparator}active-port.json',
      );
    } else {
      final currentDir = Directory.current.path;
      return File(
        '$currentDir${Platform.pathSeparator}integration${Platform.pathSeparator}zalo-bot-service${Platform.pathSeparator}.data${Platform.pathSeparator}active-port.json',
      );
    }
  }

  /// Cập nhật cổng Backend vào file zalo_settings.json
  static Future<void> _updateSettingsPort(int port) async {
    try {
      final settingsFile = File('zalo_settings.json');
      Map<String, dynamic> jsonMap = {};
      if (await settingsFile.exists()) {
        final content = await settingsFile.readAsString();
        jsonMap = jsonDecode(content) as Map<String, dynamic>;
      }

      jsonMap['zaloBackendBaseUrl'] = 'http://127.0.0.1:$port';

      final content = const JsonEncoder.withIndent('  ').convert(jsonMap);
      await settingsFile.writeAsString(content);
      debugPrint(
        "ZaloBackendManager: Đã tự động cập nhật zalo_settings.json với URL backend: http://127.0.0.1:$port",
      );
    } catch (e) {
      debugPrint(
        "ZaloBackendManager: Lỗi cập nhật cổng vào zalo_settings.json: $e",
      );
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
