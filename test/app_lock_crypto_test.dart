import 'package:alpha_crm/features/security/utils/app_lock_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verifies matching app lock password', () {
    final salt = AppLockCrypto.createSalt();
    final hash = AppLockCrypto.hashPassword('123456', salt);

    expect(AppLockCrypto.verifyPassword('123456', salt, hash), isTrue);
    expect(AppLockCrypto.verifyPassword('654321', salt, hash), isFalse);
  });
}
