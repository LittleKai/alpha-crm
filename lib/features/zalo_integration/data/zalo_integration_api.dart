import 'dart:convert';
import 'package:http/http.dart' as http;

class ZaloIntegrationApi {
  final String baseUrl;
  final http.Client _client;

  ZaloIntegrationApi({required String baseUrl, http.Client? client})
      : baseUrl = _normalizeUrl(baseUrl),
        _client = client ?? http.Client();

  static String _normalizeUrl(String url) {
    var cleaned = url.trim();
    if (cleaned.isEmpty) return 'http://localhost:8787';
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'http://$cleaned';
    }
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }

  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'status': 'error', 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getZaloStatus() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/zalo/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {
        'connected': false,
        'mode': 'disconnected',
        'error': 'HTTP ${response.statusCode}',
      };
    } catch (e) {
      return {
        'connected': false,
        'mode': 'disconnected',
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> testSend({
    required String recipientId,
    required String message,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/test-send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'recipientId': recipientId,
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fetchGroups() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/zalo/groups'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> leaveGroup({
    required String groupId,
    required bool silent,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/groups/leave'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'groupId': groupId,
              'silent': silent,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fetchAccounts() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/zalo/accounts'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteAccount(String accountId) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/accounts/delete'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'accountId': accountId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createQrSession() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/zalo/accounts/create-qr'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkSessionStatus(String sessionId) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/zalo/accounts/check-session?id=$sessionId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fetchFriends() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/zalo/friends'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> searchUserByPhone({
    required String phone,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/friends/search'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendFriendRequest({
    required String userId,
    required String message,
    String actionType = 'friend_by_phone',
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/friends/add'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'message': message,
              'actionType': actionType,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> acceptFriendRequest({
    required String senderId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/friends/approve'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'senderId': senderId}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fetchGroupMembers({
    required String groupId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/groups/members'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'groupId': groupId}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fetchGroupLinkMembers({
    required String link,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/groups/link-members'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'link': link}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    required List<String> members,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/groups/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'members': members,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> joinGroup({
    required String link,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/groups/join'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'link': link,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> inviteToGroup({
    required String userId,
    required String groupId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/groups/invite'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'groupId': groupId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  void dispose() {
    _client.close();
  }
}
