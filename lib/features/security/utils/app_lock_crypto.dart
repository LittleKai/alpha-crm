import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';

class AppLockCrypto {
  static String createSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String hashPassword(String password, String salt) {
    List<int> digest = utf8.encode('$salt:$password');
    for (var i = 0; i < 120000; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64UrlEncode(digest);
  }

  static Future<String> hashPasswordAsync(String password, String salt) {
    return Isolate.run(() => hashPassword(password, salt));
  }

  static bool verifyPassword(
    String password,
    String salt,
    String expectedHash,
  ) {
    if (salt.isEmpty || expectedHash.isEmpty) return false;
    final actual = utf8.encode(hashPassword(password, salt));
    final expected = utf8.encode(expectedHash);
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  static Future<bool> verifyPasswordAsync(
    String password,
    String salt,
    String expectedHash,
  ) {
    if (salt.isEmpty || expectedHash.isEmpty) return Future.value(false);
    return Isolate.run(() => verifyPassword(password, salt, expectedHash));
  }
}
