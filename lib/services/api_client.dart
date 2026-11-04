import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'session.dart';

export 'session.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// JSON over HTTP to the backend. Turns every failure into an [AuthException]
/// with a message that is safe to show. Pass [auth] to send the session token.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const _timeout = Duration(seconds: 10);
  static const _networkMsg =
      'Cannot reach the server. Check your connection and try again.';
  static const _serverMsg = 'Server error. Please try again later.';

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body,
          {bool auth = false}) async =>
      _asMap(await _send('POST', path, body: body, auth: auth));

  Future<Map<String, dynamic>> getMap(String path,
          {Map<String, String>? query}) async =>
      _asMap(await _send('GET', path, query: query, auth: true));

  Future<List<dynamic>> getList(String path,
      {Map<String, String>? query}) async {
    final data = await _send('GET', path, query: query, auth: true);
    if (data is! List) throw AuthException(_serverMsg);
    return data;
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is! Map) throw AuthException(_serverMsg);
    return Map<String, dynamic>.from(data);
  }

  Future<Object?> _send(String method, String path,
      {Map<String, dynamic>? body,
      Map<String, String>? query,
      required bool auth}) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final headers = <String, String>{
      if (body != null) 'Content-Type': 'application/json',
      if (auth && Session.token != null)
        'Authorization': 'Bearer ${Session.token}',
    };
    final http.Response res;
    try {
      final future = method == 'GET'
          ? _client.get(uri, headers: headers)
          : _client.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      res = await future.timeout(_timeout);
    } on TimeoutException {
      throw AuthException('The server took too long to respond. Try again.');
    } on http.ClientException {
      throw AuthException(_networkMsg);
    } catch (_) {
      throw AuthException(_networkMsg);
    }

    if (res.statusCode >= 500) throw AuthException(_serverMsg);

    Object? json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      json = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (json == null) throw AuthException(_serverMsg);
      return json;
    }

    final msg = json is Map ? json['message'] : null;
    if (msg is String && msg.isNotEmpty) throw AuthException(msg);
    if (res.statusCode == 401) {
      throw AuthException(auth
          ? 'Your session has expired. Please log in again.'
          : 'Incorrect credentials.');
    }
    throw AuthException('Request failed. Please check your input.');
  }
}
