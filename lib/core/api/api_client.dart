// lib/core/api/api_client.dart

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Thrown for anything the user should see a message about.
class ApiException implements Exception {
  final String message;
  final String code;
  final int status;

  ApiException(this.message, {this.code = 'ERROR', this.status = 0});

  bool get isAuth => status == 401;
  bool get isNetwork => code == 'NETWORK';

  @override
  String toString() => message;
}

/// Single HTTP entry point. Every repository goes through this.
///
/// Handles the `{success, message, data, error_code}` envelope, attaches the
/// token, and surfaces one clean exception type.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _http = http.Client();
  String? _token;

  /// Called once on app start.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.kToken);
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.kToken, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.kToken);
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Set by main.dart so a 401 anywhere can bounce the user to login.
  void Function()? onUnauthorised;

  // ---------------------------------------------------------------- verbs
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send('POST', path, body: body, query: query);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  // ---------------------------------------------------------------- core
  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path, query);

    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (hasToken) 'Authorization': 'Bearer $_token',
    };

    http.Response res;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);

      final streamed = await _http.send(request).timeout(AppConstants.apiTimeout);
      res = await http.Response.fromStream(streamed);
    } on SocketException {
      throw ApiException(
        'No internet connection. Check your network and try again.',
        code: 'NETWORK',
      );
    } on HttpException {
      throw ApiException('Could not reach the server.', code: 'NETWORK');
    } catch (_) {
      throw ApiException(
        'Something went wrong. Please try again.',
        code: 'NETWORK',
      );
    }

    return _unwrap(res);
  }

  Uri _uri(String path, Map<String, dynamic>? query) {
    final base = Uri.parse('${AppConstants.apiBaseUrl}$path');
    if (query == null || query.isEmpty) return base;

    final params = <String, String>{};
    query.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) params[k] = v.toString();
    });
    return base.replace(queryParameters: {...base.queryParameters, ...params});
  }

  dynamic _unwrap(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'The server sent an unexpected response.',
        code: 'BAD_RESPONSE',
        status: res.statusCode,
      );
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json['data'];
    }

    // FastAPI wraps our envelope inside `detail` on errors
    final detail = json['detail'] is Map ? json['detail'] as Map : json;
    final message = (detail['message'] ?? 'Something went wrong.').toString();
    final code = (detail['error_code'] ?? 'HTTP_${res.statusCode}').toString();

    if (res.statusCode == 401) {
      clearToken();
      onUnauthorised?.call();
    }

    throw ApiException(message, code: code, status: res.statusCode);
  }

  // ---------------------------------------------------------------- upload
  Future<String> uploadFile({
    required String folder,
    required File file,
  }) async {
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    if (hasToken) request.headers['Authorization'] = 'Bearer $_token';

    try {
      final streamed = await request.send().timeout(AppConstants.uploadTimeout);
      final res = await http.Response.fromStream(streamed);
      final data = _unwrap(res);
      return data['url'] as String;
    } on SocketException {
      throw ApiException('No internet connection.', code: 'NETWORK');
    }
  }
}
