import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  Logger? _customLogger;
  Logger get _logger {
    _customLogger ??= Logger(
        filter: _AlwaysLogFilter(),
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 4,
          lineLength: 120,
          colors: false,
          printEmojis: true,
          dateTimeFormat: DateTimeFormat.dateAndTime,
        ),
        output: ConsoleOutput(),
      );
    return _customLogger!;
  }
  File? _logFile;
  bool _isInitialized = false;

  /// Vòng đệm log gần nhất trong bộ nhớ (mới ở cuối) để splash/UI hiển thị và
  /// cho người dùng copy gửi nhà phát triển — hoạt động cả khi file log chưa tạo.
  static const int _ringCapacity = 300;
  final List<String> _ring = <String>[];

  /// Các dòng log gần nhất, một dòng mỗi mục (mới ở cuối).
  String get recentLogsText => _ring.join('\n');

  /// Lấy danh sách các dòng log gần đây dưới dạng danh sách các chuỗi (mới ở cuối).
  List<String> get recentLogs => List.unmodifiable(_ring);

  /// Xóa toàn bộ nhật ký trong bộ nhớ và xóa/ghi đè file log hiện tại.
  void clearLogs() {
    _ring.clear();
    final file = _logFile;
    if (file != null) {
      _writeQueue = _writeQueue.then((_) async {
        try {
          await file.writeAsString(
            '=== LOG RESET @ ${DateTime.now().toIso8601String()} ===\n',
            mode: FileMode.write,
          );
        } catch (e) {
          debugPrint('Failed to clear log file: $e');
        }
      });
    }
  }

  /// Đường dẫn file log hiện hành (null nếu chưa tạo được).
  String? get logFilePath => _logFile?.path;

  /// Hàng đợi ghi file (nối tiếp) để các dòng KHÔNG bị xen kẽ/cắt vụn.
  Future<void> _writeQueue = Future<void>.value();

  Future<void> init() async {
    if (_isInitialized) return;

    // PrettyPrinter CHỈ dùng cho console (đẹp khi debug). File ghi 1 dòng sạch
    // qua _appendCleanLine để dễ đọc, không khung viền/stack-trace.
    _customLogger = Logger(
      filter: _AlwaysLogFilter(),
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 4,
        lineLength: 120,
        colors: !Platform.isWindows,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.dateAndTime,
      ),
      output: ConsoleOutput(),
    );

    final fileName =
        'app_log_${DateTime.now().toIso8601String().replaceAll(':', '-')}.txt';

    // Thử thư mục Documents (qua path_provider). Nếu lỗi (plugin chưa sẵn sàng
    // trong bản đóng gói), FALLBACK ghi log cạnh file thực thi để KHÔNG bao giờ
    // mất log.
    Directory? logDirectory;
    try {
      final directory = await getApplicationDocumentsDirectory();
      logDirectory = Directory('${directory.path}/AlphaCRM/Logs');
    } catch (e) {
      debugPrint('getApplicationDocumentsDirectory lỗi, fallback cạnh exe: $e');
    }

    logDirectory ??= () {
      try {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        return Directory('$exeDir/logs');
      } catch (_) {
        return Directory('logs');
      }
    }();

    try {
      if (!await logDirectory.exists()) {
        await logDirectory.create(recursive: true);
      }
      await _pruneOldLogFiles(logDirectory);
      _logFile = File('${logDirectory.path}/$fileName');
      // Ghi ngay một dòng để xác nhận file log hoạt động.
      await _logFile!.writeAsString(
        '=== LOG FILE INIT @ ${DateTime.now().toIso8601String()} '
        '(dir: ${logDirectory.path}) ===\n',
        mode: FileMode.append,
      );
    } catch (e) {
      debugPrint('Failed to initialize local log file: $e');
      _logFile = null;
    }

    _isInitialized = true;
  }

  /// Số file log giữ lại. Mỗi lần mở app tạo một file mới và trước đây không bao
  /// giờ xoá — đo trên máy dev: 231 file tồn đọng.
  static const int _keepLogFiles = 20;

  /// Tên các file cần xoá, cũ nhất trước. Tên file mang timestamp ISO nên thứ tự
  /// từ điển trùng với thứ tự thời gian.
  @visibleForTesting
  static List<String> logFilesToPrune(
    List<String> fileNames, {
    int keep = _keepLogFiles,
  }) {
    final logs = fileNames
        .where((name) => name.startsWith('app_log_') && name.endsWith('.txt'))
        .toList()
      ..sort();
    if (logs.length <= keep) return const <String>[];
    return logs.sublist(0, logs.length - keep);
  }

  Future<void> _pruneOldLogFiles(Directory directory) async {
    try {
      final names = await directory
          .list()
          .where((entity) => entity is File)
          .map((entity) => entity.uri.pathSegments.last)
          .toList();
      for (final name in logFilesToPrune(names)) {
        try {
          await File('${directory.path}/$name').delete();
        } catch (_) {
          // File đang bị tiến trình khác giữ — bỏ qua, lần mở app sau dọn tiếp.
        }
      }
    } catch (e) {
      debugPrint('Không dọn được log cũ: $e');
    }
  }

  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
    _appendCleanLine('INFO', message, error);
  }

  /// [report] = false cho những dòng vốn ĐẾN TỪ backend (stdout/stderr đã được
  /// pipe về đây). Gửi ngược chúng xuống backend là tạo vòng lặp: backend xả
  /// stderr → mỗi dòng thành một POST → backend ghi log → xả stderr tiếp.
  void warning(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
    bool report = true,
  ]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    _appendCleanLine('WARN', message, error);
    if (report) _reportToBackend(message, error, stackTrace);
  }

  void error(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
    bool report = true,
  ]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _appendCleanLine('ERROR', message, error);
    if (report) _reportToBackend(message, error, stackTrace);
  }

  void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
    _appendCleanLine('FATAL', message, error);
    _reportToBackend(message, error, stackTrace);
  }

  /// Ghi 1 dòng sạch `HH:mm:ss.mmm [LEVEL] message [| error]` vào file, nối tiếp
  /// qua hàng đợi để không bị xen kẽ giữa các lần ghi bất đồng bộ.
  void _appendCleanLine(String level, String message, dynamic error) {
    final ts = DateTime.now().toIso8601String();
    final errPart = error != null ? '  |  $error' : '';
    final line = '$ts [$level] $message$errPart';

    // Lưu vào vòng đệm trong bộ nhớ TRƯỚC (kể cả khi file log chưa sẵn sàng) để
    // splash chẩn đoán lỗi luôn có dữ liệu.
    _ring.add(line);
    if (_ring.length > _ringCapacity) {
      _ring.removeRange(0, _ring.length - _ringCapacity);
    }

    final file = _logFile;
    if (file == null) return;
    _writeQueue = _writeQueue.then((_) async {
      try {
        await file.writeAsString('$line\n', mode: FileMode.append);
      } catch (e) {
        debugPrint('Failed to write to log file: $e');
      }
    });
  }

  /// Cổng backend cục bộ đang chạy thật, do [ZaloBackendManager] cập nhật.
  ///
  /// Trước đây địa chỉ report bị hardcode 28080: chạy ở cổng dự phòng thì log
  /// lỗi mất trắng, mà tệ hơn là nếu 28080 do ứng dụng khác chiếm thì message +
  /// stack trace của mình bị POST sang tiến trình lạ.
  static int? backendPort;

  /// Chống dồn dập: một trận lỗi không được biến thành một trận HTTP POST, vì
  /// mỗi POST khiến backend ghi thêm một bản ghi trên chính event loop của nó.
  static const int _maxReportsPerWindow = 20;
  static const Duration _reportWindow = Duration(minutes: 1);
  static const Duration _duplicateWindow = Duration(seconds: 10);

  final List<DateTime> _reportTimes = <DateTime>[];
  final Map<String, DateTime> _lastReportedAt = <String, DateTime>{};

  /// Có được phép gửi [message] lên backend tại thời điểm [now] không.
  /// Chặn khi trùng nội dung trong 10s, hoặc quá 20 lượt trong 1 phút.
  bool _shouldReport(String message, DateTime now) {
    final lastSame = _lastReportedAt[message];
    if (lastSame != null && now.difference(lastSame) < _duplicateWindow) {
      return false;
    }
    _reportTimes.removeWhere((t) => now.difference(t) >= _reportWindow);
    if (_reportTimes.length >= _maxReportsPerWindow) return false;

    _reportTimes.add(now);
    _lastReportedAt[message] = now;
    // Bảng dedupe không được phình theo số thông điệp khác nhau.
    if (_lastReportedAt.length > 200) {
      final stale = _lastReportedAt.entries
          .where((e) => now.difference(e.value) >= _duplicateWindow)
          .map((e) => e.key)
          .toList();
      for (final key in stale) {
        _lastReportedAt.remove(key);
      }
    }
    return true;
  }

  @visibleForTesting
  bool shouldReportForTest(String message, DateTime now) =>
      _shouldReport(message, now);

  @visibleForTesting
  void resetReportThrottleForTest() {
    _reportTimes.clear();
    _lastReportedAt.clear();
  }

  Future<void> _reportToBackend(String message, dynamic error, StackTrace? stackTrace) async {
    if (!kReleaseMode) return; // Chỉ tự động gửi log trong môi trường production (Release)

    final port = backendPort;
    if (port == null) return; // Chưa dò được cổng — không đoán bừa.
    if (!_shouldReport(message, DateTime.now())) return;

    try {
      final payload = {
        'message': message,
        'error': error?.toString(),
        'stackTrace': stackTrace?.toString(),
        'platform': Platform.operatingSystem,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await http.post(
        Uri.parse('http://127.0.0.1:$port/api/logs/client'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Failed to report log to backend: $e');
    }
  }
}

/// Filter luôn cho phép ghi (mọi cấp độ, kể cả Release). Logger mặc định chặn
/// info/debug ở Release khiến log chẩn đoán bị mất.
class _AlwaysLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => true;
}
