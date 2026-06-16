# SPEC Phase 2 — Flutter: clean shutdown, liveness & observability

## Goal

Make backend shutdown and failure handling robust:
1. **Tree-kill** the backend on exit so no orphaned `node.exe` keeps holding port 8787.
2. **Liveness short-circuit** in `waitUntilReady()` — stop waiting immediately if the backend
   process already exited, and poll the **detected** port (not always 8787).
3. **Observability** — route backend stdout/stderr and startup failures through the existing
   `AppLogger` (which writes a file log and, in release, POSTs to the backend), and expose a
   `lastStartupError` for the UI/log.
4. **Bounded startup retry** in `main.dart` so a slow/failed first attempt gets one more try
   instead of silently leaving the app with no backend.

## Context Pack (read this; do not explore further)

**Files to modify (only these two):**
- `D:\Dev\NodeJS\alpha-studio\tools\alpha-crm\lib\shared\utils\zalo_backend_manager.dart`
- `D:\Dev\NodeJS\alpha-studio\tools\alpha-crm\lib\main.dart`

**`AppLogger` API (singleton — file: `lib/shared/utils/app_logger.dart`):**
```dart
final logger = AppLogger();        // returns the singleton
logger.info(String message);       // file + console only
logger.warning(String message);    // also POSTs to backend in release mode
logger.error(String message);      // also POSTs to backend in release mode
```
`AppLogger().init()` is already awaited early in `main.dart` before the backend starts, so the
logger is ready by the time these code paths run.

**Current `main.dart` startup block (verbatim anchor — lines around the backend start):**
```dart
  // Tự động chạy Zalo Bot backend khi chạy trên máy tính (Desktop)
  await ZaloBackendManager.startBackend();

  // Chờ backend sẵn sàng trước khi khởi động Flutter UI (tránh lỗi auth sync)
  await ZaloBackendManager.waitUntilReady();

  runApp(const ProviderScope(child: MyApp()));
```
`main.dart` already has these imports near the top:
```dart
import 'shared/utils/zalo_backend_manager.dart';
import 'shared/utils/app_logger.dart';
```
and already creates `final appLogger = AppLogger();` before `appLogger.init()`.

**Current `waitUntilReady()` uses `final port = _activePort ?? 8787;`** and has no liveness check.
**Current `stopBackend()` only calls `_backendProcess!.kill()`** (kills the direct process; on a
`.cmd` fallback this would leave the child `node.exe` orphaned — hence the tree-kill).

**`stopBackend()` is `void` (synchronous)** and is called from `dispose()` and
`didChangeAppLifecycleState`. Use `Process.runSync` for the tree-kill (do not make it async).

## No-Placeholder Contract

This phase must ship working behavior. No TODO-only code, no empty methods, no mock returns.

## Deferred Work

None.

## Steps

### Step 1 — Import AppLogger and add observability/liveness fields

**File:** `lib/shared/utils/zalo_backend_manager.dart`
**Location anchor (import):** After the existing line `import 'package:http/http.dart' as http;`.
**Action:** Add:
```dart
import 'app_logger.dart';
```
**Location anchor (fields):** After the line you added in Phase 1 (`static String? _backendWorkingDir;`).
**Action:** Add:
```dart
  /// Đặt true khi tiến trình backend thoát sớm (dùng để dừng chờ readiness).
  static bool _backendExited = false;

  /// Thông điệp lỗi khởi động gần nhất (để UI/log tham chiếu). Null nếu không có.
  static String? _lastStartupError;

  /// Lỗi khởi động backend gần nhất (đọc-only cho UI/log).
  static String? get lastStartupError => _lastStartupError;
```
**Do NOT:** remove or rename Phase 1 fields.

### Step 2 — Route backend stdout/stderr to the file log

**File:** `lib/shared/utils/zalo_backend_manager.dart`
**Location anchor:** Inside `startBackend()`, the two existing listener blocks:
```dart
      _backendProcess!.stdout.listen((data) {
        debugPrint("ZaloBot-Log: ${String.fromCharCodes(data).trim()}");
      });
      _backendProcess!.stderr.listen((data) {
        debugPrint("ZaloBot-Error-Log: ${String.fromCharCodes(data).trim()}");
      });
```
**Action:** Replace those two blocks with:
```dart
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
```
**Do NOT:** change any other line inside `startBackend()`.

### Step 3 — Replace `waitUntilReady()` with a liveness-aware version

**File:** `lib/shared/utils/zalo_backend_manager.dart`
**Location anchor:** The entire existing method `static Future<bool> waitUntilReady(...) async { ... }`.
**Action:** Replace it with exactly:
```dart
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
```
**Do NOT:** change the default `timeout` value's call sites.

### Step 4 — Replace `stopBackend()` with a tree-kill version

**File:** `lib/shared/utils/zalo_backend_manager.dart`
**Location anchor:** The entire existing method `static void stopBackend() { ... }`.
**Action:** Replace it with exactly:
```dart
  /// Tắt tiến trình chạy ngầm khi đóng ứng dụng (diệt cả cây con để tránh node.exe mồ côi).
  static void stopBackend() {
    if (_backendProcess != null && _isRunning) {
      debugPrint(
        "ZaloBackendManager: Đang ngắt tiến trình chạy ngầm backend...",
      );
      final pid = _backendProcess!.pid;
      // Trên Windows, kill() chỉ giết tiến trình trực tiếp. Khi chạy qua launcher .cmd,
      // node.exe là tiến trình con và sẽ mồ côi (giữ cổng 8787). taskkill /T /F diệt cả cây.
      if (Platform.isWindows) {
        try {
          Process.runSync('taskkill', ['/PID', '$pid', '/T', '/F']);
        } catch (e) {
          debugPrint("ZaloBackendManager: taskkill thất bại: $e");
        }
      }
      _backendProcess!.kill();
      _backendProcess = null;
      _isRunning = false;
      debugPrint("ZaloBackendManager: Đã ngắt tiến trình backend hoàn toàn.");
    }
  }
```
**Do NOT:** make `stopBackend` async; keep it `void`.

### Step 5 — Bounded startup retry in `main.dart`

**File:** `lib/main.dart`
**Location anchor:** The block shown in the Context Pack (the three statements from
`// Tự động chạy Zalo Bot backend...` through `await ZaloBackendManager.waitUntilReady();`),
i.e. everything between `appLogger`/error-handler setup and the final `runApp(...)`.
**Action:** Replace those backend lines (keep the final `runApp(...)` line as-is) with:
```dart
  // Tự động chạy Zalo Bot backend trên Desktop và chờ sẵn sàng.
  // Thử tối đa 2 lần để chịu được khởi động chậm hoặc lỗi tạm thời.
  bool backendReady = false;
  for (int attempt = 1; attempt <= 2 && !backendReady; attempt++) {
    final started = await ZaloBackendManager.startBackend();
    if (!started) {
      appLogger.warning(
        'Backend chưa khởi động được (lần $attempt/2). '
        '${ZaloBackendManager.lastStartupError ?? ''}',
      );
      continue;
    }
    backendReady = await ZaloBackendManager.waitUntilReady();
    if (!backendReady) {
      appLogger.warning(
        'Backend khởi động nhưng chưa sẵn sàng (lần $attempt/2).',
      );
    }
  }
  if (!backendReady) {
    appLogger.error(
      'Không thể đưa backend vào trạng thái sẵn sàng sau 2 lần thử. '
      'Ứng dụng vẫn tiếp tục; các tính năng Zalo cục bộ có thể chưa hoạt động.',
    );
  }
```
**Why the retry works:** when the first `waitUntilReady` fails because the process exited, the
liveness handler (Step 3) sets `_isRunning = false`, so the second `startBackend()` will actually
re-spawn instead of short-circuiting on the `if (_isRunning) return true;` guard.
**Do NOT:** remove or move the `runApp(const ProviderScope(child: MyApp()));` line; it stays right
after this block. Do NOT add new imports (both are already imported).

## Validation Plan

Run from `D:\Dev\NodeJS\alpha-studio\tools\alpha-crm`:

```bash
flutter analyze      # clean (no new error/warning)
flutter test         # all existing tests still pass (currently 98/98)

# Confirm the new behavior is wired:
rg -n "taskkill|_backendExited|lastStartupError" lib/shared/utils/zalo_backend_manager.dart
rg -n "backendReady|lần \$attempt" lib/main.dart

# Placeholder scan:
rg -n "TODO|FIXME|NotImplemented|throw UnimplementedError|placeholder" lib/shared/utils/zalo_backend_manager.dart lib/main.dart
```

Behavioral verification (manual): `flutter run -d windows`, then close the app window and confirm
in Task Manager that **no `node.exe` remains**. Re-launch and confirm the app reaches the backend
immediately (reuse path) and the log file under
`%USERPROFILE%\Documents\AlphaCRM\Logs\` contains `ZaloBot:` lines.

## Dependencies

Phase 1 must be complete (this phase relies on `_backendWorkingDir`, the direct-launch branch, and
the no-argument `_getActivePortFile()`).
