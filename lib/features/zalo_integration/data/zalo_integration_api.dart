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
    if (cleaned.isEmpty) return 'http://127.0.0.1:8787';
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'http://$cleaned';
    }
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }

  String _translateToVietnamese(String text) {
    if (text.isEmpty) return text;

    // Translate common errors
    if (text == 'Compliance check failed') {
      return 'Kiểm tra tuân thủ thất bại';
    }

    // Translate reasons using regex or simple match
    final t = text.trim();
    if (t.contains('Quiet hours active')) {
      final reg = RegExp(
        r'Quiet hours active \((.*?)\)\. Sending is paused\.?',
      );
      final match = reg.firstMatch(t);
      if (match != null && match.groupCount >= 1) {
        return 'Đang trong khung giờ nghỉ (${match.group(1)}). Tạm dừng gửi tin.';
      }
      return 'Đang trong khung giờ nghỉ. Tạm dừng gửi tin.';
    }

    if (t.contains('Daily send limit reached')) {
      final reg = RegExp(
        r'Daily send limit reached \((.*?)\)\. Wait until tomorrow\.?',
      );
      final match = reg.firstMatch(t);
      if (match != null && match.groupCount >= 1) {
        return 'Đã đạt giới hạn gửi trong ngày (${match.group(1)}). Vui lòng đợi đến ngày mai.';
      }
      return 'Đã đạt giới hạn gửi tin trong ngày. Vui lòng đợi đến ngày mai.';
    }

    if (t.contains('Stopped: ') && t.contains('report(s) received')) {
      final reg = RegExp(
        r'Stopped: (\d+) report\(s\) received\. Threshold is (\d+)\. Resolve reports before continuing\.?',
      );
      final match = reg.firstMatch(t);
      if (match != null && match.groupCount >= 2) {
        return 'Đã tạm dừng: Nhận được ${match.group(1)} báo cáo xấu (Ngưỡng giới hạn là ${match.group(2)}). Vui lòng xử lý các báo cáo trước khi tiếp tục.';
      }
      return 'Đã dừng do nhận được quá nhiều báo cáo xấu từ người dùng.';
    }

    if (t.contains('Stopped: failure rate') && t.contains('exceeds maximum')) {
      final reg = RegExp(
        r'Stopped: failure rate (\d+)% exceeds maximum (\d+)%\. Investigate errors before continuing\.?',
      );
      final match = reg.firstMatch(t);
      if (match != null && match.groupCount >= 2) {
        return 'Đã tạm dừng: Tỷ lệ gửi lỗi (${match.group(1)}%) vượt quá mức cho phép (${match.group(2)}%). Vui lòng kiểm tra nguyên nhân lỗi trước khi tiếp tục.';
      }
      return 'Đã dừng do tỷ lệ gửi thất bại vượt quá mức cho phép.';
    }

    if (t.contains('Personal account automation is disabled')) {
      return 'Tính năng tự động hóa tài khoản cá nhân hiện đã bị tắt trên máy chủ.';
    }
    if (t.contains('Friend automation is disabled')) {
      return 'Tính năng tự động kết bạn hiện đã bị tắt trên máy chủ.';
    }
    if (t.contains('Group automation is disabled')) {
      return 'Tính năng tự động hóa nhóm hiện đã bị tắt trên máy chủ.';
    }

    if (t.contains('Batch of') &&
        t.contains('exceeds human approval threshold')) {
      final reg = RegExp(
        r'Batch of (\d+) exceeds human approval threshold \((\d+)\)\. Server-side approval required\.?',
      );
      final match = reg.firstMatch(t);
      if (match != null && match.groupCount >= 2) {
        return 'Số lượng gửi hàng loạt (${match.group(1)}) vượt quá giới hạn cần phê duyệt thủ công (${match.group(2)}). Cần phê duyệt trên máy chủ.';
      }
      return 'Số lượng gửi vượt quá giới hạn phê duyệt trên máy chủ.';
    }

    if (t.contains(
      'Personal account automation is not available in Official OA mode',
    )) {
      return 'Tính năng tự động hóa tài khoản cá nhân không khả dụng ở chế độ Official OA. Vui lòng chuyển sang kênh cá nhân.';
    }

    if (t.contains('Bulk messaging by phone requires consent proof')) {
      return 'Gửi tin nhắn hàng loạt theo SĐT yêu cầu phải có bằng chứng đồng ý từ người nhận.';
    }
    if (t.contains('Bulk messaging without consent or recent interaction')) {
      return 'Không cho phép gửi tin nhắn hàng loạt khi chưa có sự đồng ý hoặc tương tác gần đây.';
    }

    if (t.contains('Batch size') && t.contains('exceeds server maximum')) {
      final reg = RegExp(
        r'Batch size (\d+) exceeds server maximum of (\d+)\.?',
      );
      final match = reg.firstMatch(t);
      if (match != null && match.groupCount >= 2) {
        return 'Số lượng gửi (${match.group(1)}) vượt quá giới hạn tối đa cho phép của máy chủ (${match.group(2)}).';
      }
      return 'Vượt quá giới hạn tối đa cho phép của máy chủ.';
    }

    if (t.contains('Mock mode only allows test sends')) {
      return 'Chế độ giả lập (Mock) chỉ cho phép gửi tin nhắn thử nghiệm.';
    }

    if (t == 'Forbidden') return 'Bị từ chối truy cập (403)';
    if (t == 'Unauthorized') {
      return 'Chưa được ủy quyền hoặc hết hạn phiên làm việc';
    }
    if (t == 'Internal Server Error') return 'Lỗi máy chủ nội bộ';

    return text;
  }

  String? _translateRiskLevel(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
        return 'Rủi ro: Thấp';
      case 'medium':
        return 'Rủi ro: Trung bình';
      case 'high':
        return 'Rủi ro: Cao';
      case 'critical':
        return 'Rủi ro: Nguy hiểm';
      default:
        return 'Rủi ro: $risk';
    }
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    if (response.statusCode == 200) {
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return {'success': false, 'error': 'Lỗi giải mã JSON: ${e.toString()}'};
      }
    }

    try {
      final bodyData = jsonDecode(response.body);
      if (bodyData is Map) {
        final err = bodyData['error'] ?? 'Lỗi hệ thống';
        final reason = bodyData['reason'];
        final risk = bodyData['riskLevel'] ?? bodyData['risk'];

        final translatedErr = _translateToVietnamese(err.toString());
        final translatedReason = reason != null
            ? _translateToVietnamese(reason.toString())
            : null;
        final riskLabel = risk != null
            ? _translateRiskLevel(risk.toString())
            : null;

        String errorMsg = translatedErr;
        if (translatedReason != null) {
          errorMsg = '$errorMsg: $translatedReason';
        }
        if (riskLabel != null) {
          errorMsg = '$errorMsg [$riskLabel]';
        }

        return {
          ...Map<String, dynamic>.from(bodyData),
          'success': false,
          'error': errorMsg,
        };
      }
    } catch (_) {}

    return {'success': false, 'error': 'Lỗi HTTP ${response.statusCode}'};
  }

  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      try {
        final bodyData = jsonDecode(response.body);
        if (bodyData is Map) {
          final err =
              bodyData['error'] ??
              bodyData['message'] ??
              'HTTP ${response.statusCode}';
          return {
            'status': 'error',
            'error': _translateToVietnamese(err.toString()),
          };
        }
      } catch (_) {}
      return {'status': 'error', 'error': 'Lỗi HTTP ${response.statusCode}'};
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
      try {
        final bodyData = jsonDecode(response.body);
        if (bodyData is Map) {
          final err =
              bodyData['error'] ??
              bodyData['message'] ??
              'HTTP ${response.statusCode}';
          return {
            'connected': false,
            'mode': 'disconnected',
            'error': _translateToVietnamese(err.toString()),
          };
        }
      } catch (_) {}
      return {
        'connected': false,
        'mode': 'disconnected',
        'error': 'Lỗi HTTP ${response.statusCode}',
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
            body: jsonEncode({'recipientId': recipientId, 'message': message}),
          )
          .timeout(const Duration(seconds: 10));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fetchGroups() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/zalo/groups'))
          .timeout(const Duration(seconds: 10));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> leaveGroup({
    required String groupId,
    required bool silent,
    String? accountId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/groups/leave'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'groupId': groupId,
              'silent': silent,
              if (accountId != null && accountId.isNotEmpty)
                'accountId': accountId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fetchAccounts() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/zalo/accounts'))
          .timeout(const Duration(seconds: 10));

      return _processResponse(response);
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

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateAccountSettings({
    required String accountId,
    required String proxy,
    required bool blockSeen,
    required bool blockTyping,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/accounts/settings'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'accountId': accountId,
              'proxy': proxy,
              'blockSeen': blockSeen,
              'blockTyping': blockTyping,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createQrSession() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/zalo/accounts/create-qr'))
          .timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkSessionStatus(String sessionId) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/zalo/accounts/check-session?id=$sessionId'),
          )
          .timeout(const Duration(seconds: 10));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fetchFriends({String? accountId}) async {
    try {
      final query = accountId != null && accountId.isNotEmpty ? '?accountId=$accountId' : '';
      final response = await _client
          .get(Uri.parse('$baseUrl/api/zalo/friends$query'))
          .timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> searchUserByPhone({
    required String phone,
    String? accountId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/friends/search'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone,
              if (accountId != null && accountId.isNotEmpty)
                'accountId': accountId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendFriendRequest({
    required String userId,
    required String message,
    String actionType = 'friend_by_phone',
    String? accountId,
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
              if (accountId != null && accountId.isNotEmpty)
                'accountId': accountId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> acceptFriendRequest({
    required String senderId,
    String? accountId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/friends/approve'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'senderId': senderId,
              if (accountId != null && accountId.isNotEmpty)
                'accountId': accountId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return _processResponse(response);
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

      return _processResponse(response);
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

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    required List<String> members,
    String? accountId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/groups/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'members': members,
              if (accountId != null && accountId.isNotEmpty)
                'accountId': accountId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> joinGroup({
    required String link,
    String? accountId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/groups/join'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'link': link,
              if (accountId != null && accountId.isNotEmpty)
                'accountId': accountId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> inviteToGroup({
    required String userId,
    required String groupId,
    String? accountId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/zalo/groups/invite'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'groupId': groupId,
              if (accountId != null && accountId.isNotEmpty)
                'accountId': accountId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  void dispose() {
    _client.close();
  }
}
