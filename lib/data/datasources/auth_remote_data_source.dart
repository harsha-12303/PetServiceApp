import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../core/network/api_config.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();
  final http.Client _client;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/users/api/login'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    return _readObject(response, 'Login');
  }

  Future<List<dynamic>> getMenuLinks(String bearerToken) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/users/api/menulinks'),
      headers: {'Authorization': 'Bearer $bearerToken'},
    ).timeout(const Duration(seconds: 20));
    final payload = _readPayload(response, 'Menu links');
    if (payload is Map && payload['records'] is List) {
      return payload['records'] as List;
    }
    if (payload is List) {
      return payload;
    }
    throw const AppException('The server returned invalid menu links.');
  }

  Map<String, dynamic> _readObject(http.Response response, String action) {
    final payload = _readPayload(response, action);
    if (payload is Map) return Map<String, dynamic>.from(payload);
    throw const AppException('The server returned an invalid response.');
  }

  Object? _readPayload(http.Response response, String action) {
    Object? payload;
    try {
      payload = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw const AppException('The server returned invalid JSON.');
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return payload;
    if (payload is Map) {
      final message =
          payload['message'] ?? payload['detail'] ?? payload['error'];
      if (message is String && message.isNotEmpty) throw AppException(message);
    }
    throw AppException('$action failed (HTTP ${response.statusCode}).');
  }
}
