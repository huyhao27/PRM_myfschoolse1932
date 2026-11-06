import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myfschoolse1932/services/api_client.dart';
import 'package:myfschoolse1932/services/api_config.dart';
import 'package:myfschoolse1932/services/auth_service.dart';
import 'package:myfschoolse1932/services/school_service.dart';

import 'helpers.dart';

void main() {
  setUp(Session.clear);

  test('default prefix is /api/m and default base URL is the portal', () {
    expect(ApiConfig.prefix, '/api/m');
    expect(ApiConfig.path('/login'), '/api/m/login');
    expect(ApiConfig.baseUrl, endsWith(':8088'));
  });

  test('AuthService and SchoolService URLs start with the prefix', () async {
    final paths = <String>[];
    final client = MockClient((http.Request r) async {
      paths.add(r.url.path);
      if (r.url.path.endsWith('/login')) {
        return json(200, {'token': 'T', 'user': userJson()});
      }
      if (r.url.path.endsWith('/reset-password')) {
        return json(200, {'message': 'ok'});
      }
      if (r.url.path.endsWith('/schedule') || r.url.path.contains('/grades')) {
        return json(200, {'className': '10A1', 'items': [], 'subjects': []});
      }
      if (r.url.path.contains('/clubs/')) {
        return json(201, {'status': 'pending'});
      }
      return json(200, <Object>[]);
    });
    final auth = AuthService(client: client, baseUrl: 'http://test');
    await auth.login('0123456789', 'secret1');
    try {
      await auth.resetPassword('0123456789', 'secret2');
    } catch (_) {}
    final school =
        SchoolService(api: ApiClient(client: client, baseUrl: 'http://test'));
    for (final call in <Future<Object?> Function()>[
      school.children,
      school.requests,
      school.clubs,
      () => school.joinClub(3),
    ]) {
      try {
        await call();
      } catch (_) {}
    }
    expect(paths.length, greaterThanOrEqualTo(5));
    for (final p in paths) {
      expect(p, startsWith('${ApiConfig.prefix}/'));
    }
  });
}
