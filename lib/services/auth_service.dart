import 'package:http/http.dart' as http;

import '../models/user.dart';
import 'api_client.dart';

export 'api_client.dart' show AuthException, Session;

class AuthService {
  AuthService({http.Client? client, String? baseUrl})
      : _api = ApiClient(client: client, baseUrl: baseUrl);

  final ApiClient _api;

  static const _serverMsg = 'Server error. Please try again later.';

  Future<User> login(String identifier, String password) async {
    final data = await _api.post('/api/login', {
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
    final data = await _api.post('/api/reset-password', {
      'identifier': identifier,
      'newPassword': newPassword,
    });
    final m = data['message'];
    return m is String && m.isNotEmpty ? m : 'Password updated.';
  }
}
