import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Local-first store for per-group AI summary config + summary history.
/// Keyed by Zalo `groupId` so merged groups (same group on several accounts)
/// share one config/history. File: Documents/AlphaCRM/group_summaries.json.
///
/// ponytail: whole-file read/modify/write; fine for the handful of managed
/// groups an operator has. Move to SQLite if it ever grows large.
class GroupSummaryLocalStore {
  static Future<File?> _file() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final crmDir = Directory('${directory.path}/AlphaCRM');
      if (!await crmDir.exists()) {
        await crmDir.create(recursive: true);
      }
      return File('${crmDir.path}/group_summaries.json');
    } catch (_) {
      return null; // web/mobile without a writable docs dir → no-op
    }
  }

  static Future<Map<String, dynamic>> _readAll() async {
    try {
      final file = await _file();
      if (file == null || !await file.exists()) return {};
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeAll(Map<String, dynamic> data) async {
    try {
      final file = await _file();
      if (file == null) return;
      await file.writeAsString(jsonEncode(data));
    } catch (_) {
      // local persistence is best-effort
    }
  }

  static Map<String, dynamic> _entry(Map<String, dynamic> all, String groupId) {
    final raw = all[groupId];
    return raw is Map ? Map<String, dynamic>.from(raw) : {};
  }

  static Future<Map<String, dynamic>?> loadConfig(String groupId) async {
    final all = await _readAll();
    final entry = _entry(all, groupId);
    return entry['config'] is Map
        ? Map<String, dynamic>.from(entry['config'] as Map)
        : null;
  }

  static Future<void> saveConfig(
    String groupId,
    Map<String, dynamic> config,
  ) async {
    final all = await _readAll();
    final entry = _entry(all, groupId);
    entry['config'] = config;
    all[groupId] = entry;
    await _writeAll(all);
  }

  static Future<List<Map<String, dynamic>>> loadSummaries(
    String groupId,
  ) async {
    final all = await _readAll();
    final entry = _entry(all, groupId);
    final list = entry['summaries'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<void> saveSummaries(
    String groupId,
    List<Map<String, dynamic>> summaries,
  ) async {
    final all = await _readAll();
    final entry = _entry(all, groupId);
    entry['summaries'] = summaries;
    all[groupId] = entry;
    await _writeAll(all);
  }

  static Future<List<Map<String, dynamic>>> loadInsights(
    String groupId,
  ) async {
    final all = await _readAll();
    final entry = _entry(all, groupId);
    final list = entry['insights'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<void> saveInsights(
    String groupId,
    List<Map<String, dynamic>> insights,
  ) async {
    final all = await _readAll();
    final entry = _entry(all, groupId);
    entry['insights'] = insights;
    all[groupId] = entry;
    await _writeAll(all);
  }
}
