import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalAiKeyStore {
  static Future<File> _getFile() async {
    // Save to Documents/AlphaCRM as requested for local safety
    final directory = await getApplicationDocumentsDirectory();
    final crmDir = Directory('${directory.path}/AlphaCRM');
    if (!await crmDir.exists()) {
      await crmDir.create(recursive: true);
    }
    return File('${crmDir.path}/ai_api_keys.json');
  }

  static Future<Map<String, List<String>>> loadKeys() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return {};
      final jsonString = await file.readAsString();
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) return {};
      
      final result = <String, List<String>>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        if (entry.value is List) {
          final keys = (entry.value as List)
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
          if (keys.isNotEmpty) result[key] = keys;
        }
      }
      return result;
    } catch (e) {
      print('Error loading local AI keys: $e');
      return {};
    }
  }

  static Future<void> saveKeys(Map<String, List<String>> keys) async {
    try {
      final file = await _getFile();
      final jsonString = jsonEncode(keys);
      await file.writeAsString(jsonString);
    } catch (e) {
      print('Error saving local AI keys: $e');
    }
  }
}
