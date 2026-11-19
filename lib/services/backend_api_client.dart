import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

class BackendApiClient {
  BackendApiClient._();

  static final BackendApiClient instance = BackendApiClient._();
  static const String _tokenKey = 'pocketpilot_backend_access_token';
  static const Duration _timeout = Duration(seconds: 15);

  String? _accessToken;

  bool get isConfigured => AppConfig.isBackendConfigured;

  Uri _uri(String path) {
    final base = AppConfig.apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final suffix = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$suffix');
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = _accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
  }

  Future<bool> ping() async {
    final response = await get('/health');
    return response.statusCode == 200;
  }

  Future<void> setToken(String token) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<http.Response> get(String path) {
    return http.get(_uri(path), headers: _headers).timeout(_timeout);
  }

  Future<http.Response> postJson(String path, Object body) {
    return http
        .post(
          _uri(path),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);
  }

  Future<http.Response> putJson(String path, Object body) {
    return http
        .put(
          _uri(path),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);
  }

  Future<http.Response> delete(String path) {
    return http.delete(_uri(path), headers: _headers).timeout(_timeout);
  }
}
