import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myfschoolse1932/services/auth_service.dart';

import 'helpers.dart';

Matcher authError(Matcher m) =>
    throwsA(isA<AuthException>().having((e) => e.message, 'message', m));

void main() {
  setUp(Session.clear);

  test('login 200 returns user, stores session, sends body', () async {
    late http.Request seen;
    final s = svc((r) async {
      seen = r;
      return json(200, {'token': 'T', 'user': userJson()});
    });
    final u = await s.login('a@b.com', 'secret1');
    expect(u.name, 'Alice');
    expect(u.role, 'GV');
    expect(Session.token, 'T');
    expect(Session.user?.id, 1);
    expect(seen.url.path, '/api/login');
    expect(jsonDecode(seen.body),
        {'identifier': 'a@b.com', 'password': 'secret1'});
  });

  test('login 401 throws backend message', () async {
    final s = svc((_) async => json(401, {'message': 'Wrong password'}));
    await expectLater(() => s.login('a@b.com', 'x'), authError(equals('Wrong password')));
  });

  test('login 400 throws backend message', () async {
    final s = svc((_) async => json(400, {'message': 'Missing field'}));
    await expectLater(() => s.login('a', 'b'), authError(equals('Missing field')));
  });

  test('login 500 gives friendly message', () async {
    final s = svc((_) async => http.Response('boom', 500));
    await expectLater(() => s.login('a', 'b'), authError(contains('Server error')));
  });

  testWidgets('login timeout gives friendly message', (t) async {
    final s = svc((_) => Completer<http.Response>().future);
    Object? err;
    unawaited(() async {
      try {
        await s.login('a', 'b');
      } catch (e) {
        err = e;
      }
    }());
    await t.pump(const Duration(seconds: 11));
    expect(err, isA<AuthException>());
    expect((err as AuthException).message, contains('too long'));
  });

  test('login socket error gives friendly message', () async {
    final s = svc((_) async => throw const SocketException('down'));
    await expectLater(() => s.login('a', 'b'), authError(contains('Cannot reach')));
  });

  test('login invalid JSON on 200 does not crash', () async {
    final s = svc((_) async => http.Response('<html>', 200));
    await expectLater(() => s.login('a', 'b'), throwsA(isA<AuthException>()));
  });

  test('login 200 with missing token/user is handled', () async {
    final s = svc((_) async => json(200, {'foo': 1}));
    await expectLater(() => s.login('a', 'b'), throwsA(isA<AuthException>()));
  });

  test('login 401 with non-JSON body falls back to generic message', () async {
    final s = svc((_) async => http.Response('nope', 401));
    await expectLater(() => s.login('a', 'b'), authError(isNotEmpty));
  });

  test('resetPassword 200 returns message', () async {
    late http.Request seen;
    final s = svc((r) async {
      seen = r;
      return json(200, {'message': 'Done'});
    });
    expect(await s.resetPassword('a@b.com', 'newpass1'), 'Done');
    expect(jsonDecode(seen.body),
        {'identifier': 'a@b.com', 'newPassword': 'newpass1'});
  });

  test('resetPassword 404 throws backend message', () async {
    final s = svc((_) async => json(404, {'message': 'User not found'}));
    await expectLater(() => s.resetPassword('a@b.com', 'newpass1'),
        authError(equals('User not found')));
  });
}

