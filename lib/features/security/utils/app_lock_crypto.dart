import 'dart:convert';
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

  static bool verifyPassword(
    String password,
    String salt,
    String expectedHash,
  ) {
    if (salt.isEmpty || expectedHash.isEmpty) return false;
    return hashPassword(password, salt) == expectedHash;
  }
}
