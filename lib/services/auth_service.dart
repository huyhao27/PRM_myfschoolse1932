import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user.dart';
import 'api_config.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Minimal in-memory session.
class Session {
  static String? token;
  static User? user;

  static void clear() {
    token = null;
    user = null;
  }
}

class AuthService {
  AuthService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const _timeout = Duration(seconds: 10);
  static const _networkMsg =
      'Cannot reach the server. Check your connection and try again.';
  static const _serverMsg = 'Server error. Please try again later.';

  Future<User> login(String identifier, String password) async {
    final data = await _post('/api/login', {
      'identifier': identifier,
      'password': password,
    });
    final token = data['token'];
    final userJson = data['user'];
    if (token is! String || userJson is! Map) {
      throw AuthException(_serverMsg);
    }
    final user = User.fromJson(Map<String, dynamic>.from(userJson));
    Session.token = token;
    Session.user = user;
    return user;
  }

  Future<String> resetPassword(String identifier, String newPassword) async {
    final data = await _post('/api/reset-password', {
      'identifier': identifier,
      'newPassword': newPassword,
    });
    final m = data['message'];
    return m is String && m.isNotEmpty ? m : 'Password updated.';
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw AuthException('The server took too long to respond. Try again.');
    } on http.ClientException {
      throw AuthException(_networkMsg);
    } catch (_) {
      throw AuthException(_networkMsg);
    }

    if (res.statusCode >= 500) throw AuthException(_serverMsg);

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map) json = Map<String, dynamic>.from(decoded);
    } catch (_) {
      json = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (json == null) throw AuthException(_serverMsg);
      return json;
    }

    final msg = json?['message'];
    if (msg is String && msg.isNotEmpty) throw AuthException(msg);
    if (res.statusCode == 401) {
      throw AuthException('Incorrect credentials.');
    }
    throw AuthException('Request failed. Please check your input.');
  }
}
