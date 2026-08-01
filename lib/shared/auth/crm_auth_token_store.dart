import 'token_store_native.dart' as impl;

class CrmAuthTokenStore {
  static Future<void> saveToken(String token) => impl.saveToken(token);
  static Future<String?> getToken() => impl.getToken();
  static Future<void> deleteToken() => impl.deleteToken();
}
