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

  late final Logger _logger;
  File? _logFile;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: !kIsWeb && !Platform.isWindows, // Disable colors in file/windows console for cleaner output
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.dateAndTime,
      ),
      output: MultiOutput([
        ConsoleOutput(),
        _FileOutput(this),
      ]),
    );

    if (!kIsWeb) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final logDirectory = Directory('${directory.path}/AlphaCRM/Logs');
        if (!await logDirectory.exists()) {
          await logDirectory.create(recursive: true);
        }
        final fileName = 'app_log_${DateTime.now().toIso8601String().replaceAll(':', '-')}.txt';
        _logFile = File('${logDirectory.path}/$fileName');
      } catch (e) {
        debugPrint('Failed to initialize local log file: $e');
      }
    }

    _isInitialized = true;
  }

  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    _reportToBackend(message, error, stackTrace);
  }

  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _reportToBackend(message, error, stackTrace);
  }

  void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
    _reportToBackend(message, error, stackTrace);
  }

  Future<void> writeToFile(String line) async {
    if (_logFile != null) {
      try {
        await _logFile!.writeAsString('$line\n', mode: FileMode.append);
      } catch (e) {
        debugPrint('Failed to write to log file: $e');
      }
    }
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

class _FileOutput extends LogOutput {
  final AppLogger appLogger;

  _FileOutput(this.appLogger);

  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      appLogger.writeToFile(line);
    }
  }
}
