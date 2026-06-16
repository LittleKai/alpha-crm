# SPEC Phase 1 — Flutter: reliable backend launch (`ZaloBackendManager.startBackend`)

## Goal

Rework `ZaloBackendManager.startBackend()` so the production Windows build:
1. **Reuses** an already-healthy backend instead of spawning a duplicate (reuse-or-replace).
2. **Launches `node.exe` directly** (single killable process, no console flash) when the bundled
   service is present, falling back to the existing `.cmd`/`.exe`/`.bat` launcher otherwise.
3. **Reads `active-port.json` from the correct service directory** in every mode, so dynamic-port
   detection actually works.

This is the heart of the "backend won't start / starts on the wrong port" fix.

## Context Pack (read this; do not explore further)

**File to modify (only this file):**
`D:\Dev\NodeJS\alpha-studio\tools\alpha-crm\lib\shared\utils\zalo_backend_manager.dart`

**Existing imports at the top of that file (already present — do not change):**
```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
```

**Existing static fields (already present — keep them, you will ADD one more):**
```dart
static Process? _backendProcess;
static bool _isRunning = false;
static int? _activePort;
```

**Production on-disk layout (why the path fix matters):**
- Launcher `zalo-bot-service.cmd` sits at `<Release>\zalo-bot-service.cmd`.
- The backend itself is staged at `<Release>\zalo-bot-service\` containing `node.exe`,
  `dist\server.js`, and `node_modules\`.
- The running backend writes its chosen port to `<Release>\zalo-bot-service\.data\active-port.json`
  (this is correct and unchanged on the backend side).
- The OLD Flutter code read `<Release>\.data\active-port.json` (wrong folder) — that is the bug.

**Backend `/health` response shape (used by the reuse probe):** HTTP 200 with a JSON body whose
`status` field equals `"ok"`. Example: `{ "status": "ok", "version": "0.2.0", ... }`.

**`_updateSettingsPort(int port)` already exists** in this file and writes
`zalo_settings.json` → `{ "zaloBackendBaseUrl": "http://127.0.0.1:<port>" }`. Reuse it as-is; do
not modify it.

**Dev fallback branch (must be preserved):** When no launcher and no bundled `node.exe` are
found and `kDebugMode` is true, the old code reads a manually-run backend's port file at
`<cwd>\integration\zalo-bot-service\.data\active-port.json`. Keep this behavior.

## No-Placeholder Contract

This phase must ship working behavior. No TODO-only code, no empty methods, no mock returns.

## Deferred Work

None.

## Steps

### Step 1 — Add a static field to remember the backend's working directory

**File:** `lib/shared/utils/zalo_backend_manager.dart`
**Location anchor:** Immediately after the existing line `static int? _activePort;`.
**Action:** Add one static field:
```dart
  /// Thư mục làm việc của backend đang chạy (chứa dist/ và .data/).
  /// Dùng để đọc đúng .data/active-port.json. Null khi chạy ở chế độ dev thủ công.
  static String? _backendWorkingDir;
```
**Do NOT:** rename `_activePort` or any existing field.

### Step 2 — Add a private `/health` probe helper

**File:** `lib/shared/utils/zalo_backend_manager.dart`
**Location anchor:** New method, place it directly **above** the existing
`static File _getActivePortFile(...)` method.
**Action:** Add:
```dart
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
```
**Do NOT:** add new imports (`http`, `dart:convert` are already imported).

### Step 3 — Replace the body of `startBackend()`

**File:** `lib/shared/utils/zalo_backend_manager.dart`
**Location anchor:** The entire existing method `static Future<bool> startBackend() async { ... }`
(from its signature through its closing brace). Replace the whole method with the version below.
The early-return guards and the dev-fallback block are reproduced inside — copy it verbatim.
**Action:** Replace `startBackend()` with exactly this:
```dart
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
          final candidateServer = '$candidateServiceDir${sep}dist${sep}server.js';
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
```
**Do NOT:** change `waitUntilReady`, `stopBackend`, or `_updateSettingsPort` in this phase
(those are Phase 2). Do NOT remove the dev-fallback block. Do NOT add packages.

### Step 4 — Replace `_getActivePortFile` to use the tracked working dir

**File:** `lib/shared/utils/zalo_backend_manager.dart`
**Location anchor:** The entire existing method
`static File _getActivePortFile(String? executablePath) { ... }`.
**Action:** Replace it (note the signature loses its parameter) with:
```dart
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
```
**Do NOT:** leave any remaining call to `_getActivePortFile(...)` with an argument — Step 3 already
calls it with no argument in both places. Verify there are zero callers passing an argument.

## Validation Plan

Run from `D:\Dev\NodeJS\alpha-studio\tools\alpha-crm`:

```bash
# 1. Static analysis — must be clean (no new error/warning)
flutter analyze

# 2. Confirm no stale argument-call to the renamed helper remains
rg "_getActivePortFile\(" lib/shared/utils/zalo_backend_manager.dart
#    Expect: only calls with empty parentheses _getActivePortFile()

# 3. Confirm the direct-launch and reuse branches exist
rg -n "Process.start" lib/shared/utils/zalo_backend_manager.dart   # expect node.exe + launcher branches
rg -n "_probeHealth|_backendWorkingDir" lib/shared/utils/zalo_backend_manager.dart

# 4. Placeholder scan on the touched file
rg -n "TODO|FIXME|NotImplemented|throw UnimplementedError|placeholder" lib/shared/utils/zalo_backend_manager.dart
#    Expect: no matches
```

Behavioral verification (manual, done in the final SPEC verification after Phase 2, because it
needs a packaged bundle / running app): launch the Windows app, confirm the backend is reached on
the detected port even when 8787 is pre-occupied, and that a second app launch reuses the running
backend rather than failing.

## Dependencies

None.
