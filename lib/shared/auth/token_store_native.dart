import 'dart:io';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

// Native (Windows/Android) CRM token storage.
//
// The token is held in the OS keystore via flutter_secure_storage
// (Windows DPAPI / Android Keystore) instead of a plaintext JSON file.
// A one-time migration imports any legacy `crm_token.json` written by older
// builds so users are not logged out by the upgrade.

const _key = 'crm_auth_token';
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

Future<File> _legacyFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/crm_token.json');
}

Future<void> saveToken(String token) async {
  try {
    await _storage.write(key: _key, value: token);
  } catch (_) {}
}

Future<String?> getToken() async {
  try {
    final token = await _storage.read(key: _key);
    if (token != null) return token;
    return await _migrateLegacyToken();
  } catch (_) {
    return null;
  }
}

Future<void> deleteToken() async {
  try {
    await _storage.delete(key: _key);
  } catch (_) {}
  try {
    final file = await _legacyFile();
    if (await file.exists()) await file.delete();
  } catch (_) {}
}

/// Imports a legacy plaintext token file into secure storage, then removes it.
Future<String?> _migrateLegacyToken() async {
  try {
    final file = await _legacyFile();
    if (!await file.exists()) return null;
    final data = jsonDecode(await file.readAsString());
    final token = data['token'] as String?;
    if (token != null && token.isNotEmpty) {
      await _storage.write(key: _key, value: token);
    }
    await file.delete();
    return token;
  } catch (_) {
    return null;
  }
}
