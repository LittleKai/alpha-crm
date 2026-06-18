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
    if (_customLogger == null) {
      _customLogger = Logger(
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
    }
    return _customLogger!;
  }
  File? _logFile;
  bool _isInitialized = false;

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
        colors: !kIsWeb && !Platform.isWindows,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.dateAndTime,
      ),
      output: ConsoleOutput(),
    );

    if (!kIsWeb) {
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
    }

    _isInitialized = true;
  }

  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
    _appendCleanLine('INFO', message, error);
  }

  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    _appendCleanLine('WARN', message, error);
    _reportToBackend(message, error, stackTrace);
  }

  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _appendCleanLine('ERROR', message, error);
    _reportToBackend(message, error, stackTrace);
  }

  void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
    _appendCleanLine('FATAL', message, error);
    _reportToBackend(message, error, stackTrace);
  }

  /// Ghi 1 dòng sạch `HH:mm:ss.mmm [LEVEL] message [| error]` vào file, nối tiếp
  /// qua hàng đợi để không bị xen kẽ giữa các lần ghi bất đồng bộ.
  void _appendCleanLine(String level, String message, dynamic error) {
    final file = _logFile;
    if (file == null) return;
    final ts = DateTime.now().toIso8601String();
    final errPart = error != null ? '  |  $error' : '';
    final line = '$ts [$level] $message$errPart\n';
    _writeQueue = _writeQueue.then((_) async {
      try {
        await file.writeAsString(line, mode: FileMode.append);
      } catch (e) {
        debugPrint('Failed to write to log file: $e');
      }
    });
  }

  Future<void> _reportToBackend(String message, dynamic error, StackTrace? stackTrace) async {
    if (!kReleaseMode) return; // Chỉ tự động gửi log trong môi trường production (Release)

    try {
      final payload = {
        'message': message,
        'error': error?.toString(),
        'stackTrace': stackTrace?.toString(),
        'platform': kIsWeb ? 'Web' : Platform.operatingSystem,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await http.post(
        Uri.parse('http://127.0.0.1:8787/api/logs/client'),
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
