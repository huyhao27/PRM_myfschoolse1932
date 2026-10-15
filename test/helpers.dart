import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myfschoolse1932/services/auth_service.dart';

Map<String, dynamic> userJson({String name = 'Alice', String role = 'GV'}) => {
      'id': 1,
      'name': name,
      'email': 'a@b.com',
      'phone': '0123456789',
      'role': role,
    };

http.Response json(int code, Object body) => http.Response(
      jsonEncode(body),
      code,
      headers: {'content-type': 'application/json'},
    );

AuthService svc(Future<http.Response> Function(http.Request) h) =>
    AuthService(client: MockClient(h), baseUrl: 'http://test');
