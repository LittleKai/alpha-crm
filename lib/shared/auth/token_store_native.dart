import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

Future<File> _getFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/crm_token.json');
}

Future<void> saveToken(String token) async {
  final file = await _getFile();
  await file.writeAsString(jsonEncode({'token': token}));
}

Future<String?> getToken() async {
  try {
    final file = await _getFile();
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    final data = jsonDecode(content);
    return data['token'] as String?;
  } catch (_) {
    return null;
  }
}

Future<void> deleteToken() async {
  try {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {}
}
