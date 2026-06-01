import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../auth/crm_auth_token_store.dart';

class CrmCloudApi {
  static const String fallbackUrl = 'https://alpha-studio-backend.fly.dev/api';
  
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('ALPHA_STUDIO_API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return fallbackUrl;
  }
  
  static Future<Map<String, String>> _headers() async {
    final token = await CrmAuthTokenStore.getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
  
  // Generic helper for GET
  static Future<Map<String, dynamic>> get(String path) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _headers();
      debugPrint('[CrmCloudApi] GET $url');
      final response = await http.get(url, headers: headers);
      return _parseResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Generic helper for POST
  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _headers();
      debugPrint('[CrmCloudApi] POST $url');
      final response = await http.post(url, headers: headers, body: jsonEncode(body));
      return _parseResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Generic helper for PUT
  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _headers();
      debugPrint('[CrmCloudApi] PUT $url');
      final response = await http.put(url, headers: headers, body: jsonEncode(body));
      return _parseResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Generic helper for DELETE
  static Future<Map<String, dynamic>> delete(String path) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _headers();
      debugPrint('[CrmCloudApi] DELETE $url');
      final response = await http.delete(url, headers: headers);
      return _parseResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Map<String, dynamic> _parseResponse(http.Response response) {
    debugPrint('[CrmCloudApi] Response Status: ${response.statusCode}');
    if (response.body.isEmpty) {
      return {
        'success': response.statusCode >= 200 && response.statusCode < 300,
        'message': 'Empty response from backend'
      };
    }
    
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {'success': true, 'data': decoded};
    } catch (e) {
      return {'success': false, 'message': 'JSON Parse Error: ${e.toString()}'};
    }
  }
}
