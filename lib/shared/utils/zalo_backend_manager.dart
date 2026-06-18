import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_logger.dart';
import 'windows_job_object.dart';

/// Trạng thái vòng đời của backend cục bộ, dùng để UI phản ứng.
enum BackendStatus {
  /// Chưa khởi động hoặc đã dừng có chủ đích (đóng app).
  stopped,

  /// Đang khởi động lần đầu.
  starting,

  /// Đang phục vụ bình thường (/health trả ok).
  healthy,

  /// Vừa lỡ một nhịp health-check, đang theo dõi trước khi khởi động lại.
  degraded,

  /// Đang tự khởi động lại sau khi phát hiện chết.
  restarting,

  /// Đã thất bại quá nhiều lần (circuit breaker mở) — chờ người dùng thử lại.
  failed,
}

/// Quản lý tiến trình chạy ngầm Node.js Zalo Bot Service trên môi trường Desktop.
///
/// Hoạt động như một supervisor: khởi động backend, giám sát /health liên tục,
/// tự khởi động lại khi tiến trình chết (có exponential backoff + circuit
/// breaker), và trói tiến trình vào Windows Job Object để không bao giờ mồ côi.
class ZaloBackendManager {
  static Process? _backendProcess;
  static bool _isRunning = false;
  static int? _activePort;

  // --- Cấu hình supervisor ---
  static const int _defaultPort = 8787;
  static const Duration _watchdogInterval = Duration(seconds: 5);

  /// Số nhịp health-check lỗi liên tiếp trước khi coi backend là chết.
  static const int _failureThreshold = 2;

  /// Số lần khởi động lại tối đa trong [_circuitWindow] trước khi mở circuit.
  static const int _maxRestartsPerWindow = 5;
  static const Duration _circuitWindow = Duration(minutes: 2);
  static const Duration _maxBackoff = Duration(seconds: 30);

  // --- Trạng thái supervisor ---
  /// Trạng thái backend cho UI lắng nghe (không cần Riverpod).
  static final ValueNotifier<BackendStatus> status =
      ValueNotifier<BackendStatus>(BackendStatus.stopped);

  static Timer? _watchdogTimer;
  static int _consecutiveFailures = 0;
  static int _restartCount = 0;
  static DateTime? _windowStart;

  /// Đang trong một chu trình (re)start — chặn watchdog kích hoạt chồng chéo.
  static bool _ensuring = false;

  /// True khi app chủ động dừng backend (đóng app / cập nhật) — chặn auto-restart.
  static bool _manualStop = false;

  /// Thư mục làm việc của backend đang chạy (chứa dist/ và .data/).
  /// Dùng để đọc đúng .data/active-port.json. Null khi chạy ở chế độ dev thủ công.
  static String? _backendWorkingDir;

  /// Đặt true khi tiến trình backend thoát sớm (dùng để dừng chờ readiness).
  static bool _backendExited = false;

  /// Thông điệp lỗi khởi động gần nhất (để UI/log tham chiếu). Null nếu không có.
  static String? _lastStartupError;

  /// Lỗi khởi động backend gần nhất (đọc-only cho UI/log).
  static String? get lastStartupError => _lastStartupError;

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
      // 2. Reuse-or-replace: nếu đã có backend khỏe mạnh ở cổng mặc định, tái sử dụng.
      const int defaultPort = 8787;
      if (await _probeHealth(defaultPort)) {
        _activePort = defaultPort;
        _isRunning = true;
        debugPrint(
          "ZaloBackendManager: Đã có backend chạy sẵn tại cổng $defaultPort, tái sử dụng (không khởi tạo trùng).",
        );
        await _updateSettingsPort(defaultPort);
        return true;
      }

      final sep = Platform.pathSeparator;
      final appDir = File(Platform.resolvedExecutable).parent.path;
      final currentDir = Directory.current.path;
      final searchDirs = appDir == currentDir ? [appDir] : [appDir, currentDir];

      // 3. Ưu tiên chạy node.exe trực tiếp: <dir>/zalo-bot-service/{node.exe, dist/server.js}
      String? nodeExePath;
      String? serverJsPath;
      String? serviceDir;
      if (Platform.isWindows) {
        for (final dir in searchDirs) {
          final candidateServiceDir = '$dir${sep}zalo-bot-service';
          final candidateNode = '$candidateServiceDir${sep}node.exe';
          // Bản đóng gói chạy bundle esbuild (server.cjs); dev fallback dùng server.js.
          final candidateServerCjs =
              '$candidateServiceDir${sep}dist${sep}server.cjs';
          final candidateServerJs =
              '$candidateServiceDir${sep}dist${sep}server.js';
          final candidateServer = await File(candidateServerCjs).exists()
              ? candidateServerCjs
              : candidateServerJs;
          if (await File(candidateNode).exists() &&
              await File(candidateServer).exists()) {
            nodeExePath = candidateNode;
            serverJsPath = candidateServer;
            serviceDir = candidateServiceDir;
            break;
          }
        }
      }

      if (nodeExePath != null && serverJsPath != null && serviceDir != null) {
        // 3a. Chế độ trực tiếp — một tiến trình node duy nhất, kill sạch, không nháy console.
        _backendWorkingDir = serviceDir;
        debugPrint(
          "ZaloBackendManager: Khởi động backend trực tiếp qua node.exe: $nodeExePath",
        );
        _backendProcess = await Process.start(
          nodeExePath,
          [serverJsPath],
          workingDirectory: serviceDir,
          mode: ProcessStartMode.normal,
        );
        _afterSpawn();
      } else {
        // 3b. Fallback: dò launcher script (.cmd/.exe/.bat) như cũ.
        final candidateNames = Platform.isWindows
            ? const [
                'zalo-bot-service.cmd',
                'zalo-bot-service.exe',
                'zalo-bot-service.bat',
              ]
            : const ['zalo-bot-service'];

        String? executablePath;
        String? launcherDir;
        for (final dir in searchDirs) {
          for (final candidateName in candidateNames) {
            final candidatePath = '$dir$sep$candidateName';
            if (await File(candidatePath).exists()) {
              executablePath = candidatePath;
              launcherDir = dir;
              break;
            }
          }
          if (executablePath != null) break;
        }

        // 3c. Không có launcher: giữ nguyên hành vi dev / cảnh báo production.
        if (executablePath == null) {
          if (kDebugMode) {
            debugPrint(
              "ZaloBackendManager (Development): Không tìm thấy launcher backend (${candidateNames.join(', ')}). "
              "Dò tìm file active-port.json để đồng bộ cổng tự động...",
            );
            final portFile = _getActivePortFile();
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
              "ZaloBackendManager (Production): Không tìm thấy backend (node.exe hoặc launcher). Vui lòng kiểm tra file đóng gói.",
            );
          }
          return false;
        }

        // 3d. Trong bản đóng gói, thư mục service nằm cạnh launcher: <launcherDir>/zalo-bot-service
        _backendWorkingDir = '$launcherDir${sep}zalo-bot-service';
        debugPrint(
          "ZaloBackendManager: Đang khởi động backend qua launcher: $executablePath",
        );
        _backendProcess = await Process.start(
          executablePath,
          [],
          runInShell: true,
          mode: ProcessStartMode.normal,
          workingDirectory: File(executablePath).parent.path,
        );
        _afterSpawn();
      }

      _isRunning = true;
      debugPrint(
        "ZaloBackendManager: Backend đã khởi động. Đang dò tìm cổng active...",
      );

      // 4. Dò cổng active từ .data/active-port.json dưới thư mục service.
      final portFile = _getActivePortFile();
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

      // 5. Lắng nghe output backend để tiện debug.
      _backendProcess!.stdout.listen((data) {
        final line = String.fromCharCodes(data).trim();
        if (line.isEmpty) return;
        debugPrint("ZaloBot-Log: $line");
        AppLogger().info("ZaloBot: $line");
      });
      _backendProcess!.stderr.listen((data) {
        final line = String.fromCharCodes(data).trim();
        if (line.isEmpty) return;
        debugPrint("ZaloBot-Error-Log: $line");
        AppLogger().error("ZaloBot stderr: $line");
      });

      return true;
    } catch (e) {
      debugPrint("ZaloBackendManager: Lỗi khi chạy backend: $e");
      _isRunning = false;
      return false;
    }
  }

  /// Chờ cho đến khi backend sẵn sàng phục vụ request (poll GET /health).
  /// Trả về true nếu backend healthy, false nếu hết thời gian chờ hoặc tiến trình đã thoát.
  static Future<bool> waitUntilReady({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      return false;
    }

    // Liveness: nếu tiến trình backend thoát sớm thì dừng chờ ngay.
    _backendExited = false;
    _backendProcess?.exitCode.then((code) {
      _backendExited = true;
      _isRunning = false;
      _lastStartupError = 'Tiến trình backend đã thoát sớm với mã $code.';
      AppLogger().error('ZaloBackendManager: $_lastStartupError');
    });

    final port = _activePort ?? 8787;
    final healthUrl = Uri.parse('http://127.0.0.1:$port/health');
    final deadline = DateTime.now().add(timeout);
    final client = http.Client();

    debugPrint(
      'ZaloBackendManager: Đang chờ backend sẵn sàng tại $healthUrl...',
    );

    try {
      while (DateTime.now().isBefore(deadline)) {
        if (_backendExited) {
          debugPrint('ZaloBackendManager: Backend đã thoát sớm, dừng chờ.');
          return false;
        }
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

    _lastStartupError =
        'Hết thời gian chờ backend sẵn sàng (${timeout.inSeconds}s).';
    debugPrint('ZaloBackendManager: $_lastStartupError');
    AppLogger().warning('ZaloBackendManager: $_lastStartupError');
    return false;
  }

  // =========================================================================
  // SUPERVISOR — giám sát liên tục, tự khởi động lại, vòng đời tiến trình chắc.
  // =========================================================================

  /// Chạy ngay sau khi spawn một tiến trình backend: trói vào Job Object để
  /// không mồ côi, và gắn listener thoát vĩnh viễn để kích hoạt auto-restart.
  static void _afterSpawn() {
    final proc = _backendProcess;
    if (proc == null) return;

    // Phase 3: trói vào Windows Job Object (KILL_ON_JOB_CLOSE).
    if (Platform.isWindows) {
      final assigned = WindowsJobObject.assignProcess(proc.pid);
      debugPrint(
        'ZaloBackendManager: Job Object ${assigned ? "đã trói" : "không trói được"} '
        'tiến trình pid=${proc.pid}.',
      );
    }

    // Listener thoát vĩnh viễn: tiến trình chết bất ngờ → kích hoạt khởi động lại.
    proc.exitCode.then((code) {
      // Chỉ xử lý nếu đây vẫn là tiến trình hiện hành (không phải bản đã bị thay).
      if (!identical(proc, _backendProcess)) return;
      _isRunning = false;
      if (_manualStop) return;
      _lastStartupError = 'Tiến trình backend thoát bất ngờ với mã $code.';
      AppLogger().error('ZaloBackendManager: $_lastStartupError');
      debugPrint('ZaloBackendManager: $_lastStartupError → tự khởi động lại.');
      _setStatus(BackendStatus.degraded);
      // Khởi động lại ngay, không đợi nhịp watchdog kế tiếp.
      unawaited(_ensureRunning());
    });
  }

  /// Điểm vào cho app: khởi động backend rồi bật watchdog giám sát liên tục.
  /// Không blocking — gọi viên (caller) có thể fire-and-forget để UI hiện ngay.
  static Future<void> startSupervised() async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      return;
    }
    _manualStop = false;
    _consecutiveFailures = 0;
    _restartCount = 0;
    _windowStart = null;
    _setStatus(BackendStatus.starting);
    await _ensureRunning();
    _startWatchdog();
  }

  /// Người dùng bấm "Thử lại" khi circuit đã mở: reset bộ đếm và khởi động lại.
  static Future<void> retryManually() async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      return;
    }
    _manualStop = false;
    _consecutiveFailures = 0;
    _restartCount = 0;
    _windowStart = null;
    _setStatus(BackendStatus.starting);
    await _ensureRunning();
    _startWatchdog();
  }

  /// Bật vòng giám sát health định kỳ (idempotent).
  static void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(_watchdogInterval, (_) => _tick());
  }

  /// Một nhịp watchdog: kiểm tra /health, chịu đựng một lần lỡ, lỗi liên tiếp
  /// quá ngưỡng thì kích hoạt khởi động lại.
  static Future<void> _tick() async {
    if (_manualStop || _ensuring) return;
    // Circuit đang mở → ngưng auto-restart, chờ retryManually().
    if (status.value == BackendStatus.failed) return;

    final port = _activePort ?? _defaultPort;
    final healthy = await _probeHealth(port);
    if (healthy) {
      _consecutiveFailures = 0;
      _isRunning = true;
      // Ổn định đủ lâu → reset circuit breaker.
      if (_windowStart != null &&
          DateTime.now().difference(_windowStart!) > _circuitWindow) {
        _windowStart = null;
        _restartCount = 0;
      }
      _setStatus(BackendStatus.healthy);
      return;
    }

    _consecutiveFailures++;
    if (_consecutiveFailures < _failureThreshold) {
      _setStatus(BackendStatus.degraded);
      return; // chịu đựng một lần lỡ tạm thời
    }
    await _ensureRunning();
  }

  /// Bảo đảm backend đang chạy & khỏe. Tự kill bản hỏng, áp dụng exponential
  /// backoff và circuit breaker rồi spawn lại + chờ sẵn sàng.
  static Future<void> _ensureRunning() async {
    if (_ensuring) return;
    _ensuring = true;
    try {
      final port = _activePort ?? _defaultPort;
      if (await _probeHealth(port)) {
        _isRunning = true;
        _consecutiveFailures = 0;
        _setStatus(BackendStatus.healthy);
        return;
      }

      // Circuit breaker theo cửa sổ thời gian.
      final now = DateTime.now();
      if (_windowStart == null ||
          now.difference(_windowStart!) > _circuitWindow) {
        _windowStart = now;
        _restartCount = 0;
      }
      if (_restartCount >= _maxRestartsPerWindow) {
        _lastStartupError =
            'Backend khởi động lại thất bại $_restartCount lần liên tiếp '
            '(circuit breaker mở). Vui lòng thử lại thủ công.';
        AppLogger().error('ZaloBackendManager: $_lastStartupError');
        _setStatus(BackendStatus.failed);
        return;
      }

      _restartCount++;
      _setStatus(
        _restartCount == 1 ? BackendStatus.starting : BackendStatus.restarting,
      );

      // Diệt bản cũ (nếu còn) rồi chờ backoff trước khi spawn lại.
      _killProcess();
      if (_restartCount > 1) {
        final backoff = _backoffFor(_restartCount);
        debugPrint(
          'ZaloBackendManager: Chờ ${backoff.inSeconds}s (backoff) trước khi '
          'khởi động lại lần $_restartCount...',
        );
        await Future.delayed(backoff);
      }

      final started = await startBackend();
      if (!started) {
        _setStatus(BackendStatus.degraded);
        return;
      }
      final ready = await waitUntilReady();
      if (ready) {
        _consecutiveFailures = 0;
        _setStatus(BackendStatus.healthy);
      } else {
        _setStatus(BackendStatus.degraded);
      }
    } finally {
      _ensuring = false;
    }
  }

  /// Exponential backoff 2^(n-1) giây, chặn trần ở [_maxBackoff].
  static Duration _backoffFor(int restartCount) {
    final seconds = math.min(
      _maxBackoff.inSeconds,
      math.pow(2, restartCount - 1).toInt(),
    );
    return Duration(seconds: seconds);
  }

  /// Diệt tiến trình backend hiện hành (cả cây con) mà KHÔNG đặt cờ dừng có chủ
  /// đích — dùng nội bộ cho restart. taskkill /T /F là fallback khi Job Object
  /// không khả dụng.
  static void _killProcess() {
    final proc = _backendProcess;
    if (proc == null) return;
    final pid = proc.pid;
    if (Platform.isWindows) {
      try {
        Process.runSync('taskkill', ['/PID', '$pid', '/T', '/F']);
      } catch (e) {
        debugPrint('ZaloBackendManager: taskkill thất bại: $e');
      }
    }
    proc.kill();
    _backendProcess = null;
    _isRunning = false;
  }

  /// Cập nhật trạng thái + thông báo cho UI (chỉ khi đổi).
  static void _setStatus(BackendStatus next) {
    if (status.value != next) {
      status.value = next;
    }
  }

  /// Kiểm tra nhanh xem đã có backend khỏe mạnh đang lắng nghe ở [port] chưa.
  static Future<bool> _probeHealth(int port) async {
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse('http://127.0.0.1:$port/health'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body is Map && body['status'] == 'ok';
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Xác định file lưu cổng của Backend: <serviceDir>/.data/active-port.json.
  /// Khi chạy dev thủ công (không có _backendWorkingDir) thì trỏ về
  /// integration/zalo-bot-service/.data/active-port.json dưới thư mục hiện hành.
  static File _getActivePortFile() {
    final sep = Platform.pathSeparator;
    final dir = _backendWorkingDir;
    if (dir != null) {
      return File('$dir$sep.data${sep}active-port.json');
    }
    final currentDir = Directory.current.path;
    return File(
      '$currentDir${sep}integration${sep}zalo-bot-service$sep.data${sep}active-port.json',
    );
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

  /// Tắt backend có chủ đích khi đóng ứng dụng / cập nhật. Dừng watchdog và đặt
  /// cờ [_manualStop] để KHÔNG kích hoạt auto-restart, rồi diệt cả cây tiến
  /// trình con để tránh node.exe mồ côi.
  static void stopBackend() {
    _manualStop = true;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    if (_backendProcess != null) {
      debugPrint(
        "ZaloBackendManager: Đang ngắt tiến trình chạy ngầm backend...",
      );
      _killProcess();
      debugPrint("ZaloBackendManager: Đã ngắt tiến trình backend hoàn toàn.");
    }
    _setStatus(BackendStatus.stopped);
  }
}
