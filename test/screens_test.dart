import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:myfschoolse1932/models/user.dart';
import 'package:myfschoolse1932/screen/fpt_logo.dart';
import 'package:myfschoolse1932/screen/home_screen.dart';
import 'package:myfschoolse1932/screen/login_screen.dart';
import 'package:myfschoolse1932/screen/widgets.dart' show roleName;
import 'package:myfschoolse1932/screen/reset_password_screen.dart';
import 'package:myfschoolse1932/services/auth_service.dart';
import 'package:myfschoolse1932/theme/app_theme.dart';

import 'helpers.dart';

Widget app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

Future<void> fillLogin(WidgetTester t,
    {String id = '0901234567', String pw = 'secret1'}) async {
  await t.enterText(find.byType(TextFormField).at(0), id);
  await t.enterText(find.byType(TextFormField).at(1), pw);
}

Finder loginBtn() => find.widgetWithText(ElevatedButton, 'Đăng nhập');

Future<void> tapLogin(WidgetTester t) async {
  await t.ensureVisible(loginBtn());
  await t.tap(loginBtn());
}

void main() {
  setUp(Session.clear);

  group('LoginScreen', () {
    testWidgets('empty submit shows errors', (t) async {
      var calls = 0;
      await t.pumpWidget(app(LoginScreen(authService: svc((_) async {
        calls++;
        return json(200, {});
      }))));
      await tapLogin(t);
      await t.pump();
      expect(find.text('Vui lòng nhập số điện thoại'), findsOneWidget);
      expect(
          find.text('Mật khẩu tối thiểu 6 ký tự'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('email is rejected: login is by phone only', (t) async {
      await t.pumpWidget(
          app(LoginScreen(authService: svc((_) async => json(200, {})))));
      await fillLogin(t, id: 'a@b.com');
      await tapLogin(t);
      await t.pump();
      expect(find.text('Số điện thoại không hợp lệ'), findsOneWidget);
    });

    testWidgets('shows FPT logo and phone label', (t) async {
      await t.pumpWidget(app(const LoginScreen()));
      expect(find.byType(FptLogo), findsOneWidget);
      expect(find.text('Số điện thoại'), findsOneWidget);
    });

    testWidgets('short password error', (t) async {
      await t.pumpWidget(
          app(LoginScreen(authService: svc((_) async => json(200, {})))));
      await fillLogin(t, pw: '123');
      await tapLogin(t);
      await t.pump();
      expect(
          find.text('Mật khẩu tối thiểu 6 ký tự'), findsOneWidget);
    });

    testWidgets('wrong credentials shows error and stays', (t) async {
      await t.pumpWidget(app(LoginScreen(
          authService:
              svc((_) async => json(401, {'message': 'Invalid credentials'})))));
      await fillLogin(t);
      await tapLogin(t);
      await t.pumpAndSettle();
      expect(find.text('Sai tài khoản hoặc mật khẩu'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(t.widget<ElevatedButton>(loginBtn()).onPressed, isNotNull);
    });

    testWidgets('network error shows friendly text', (t) async {
      await t.pumpWidget(app(LoginScreen(
          authService: svc((_) async => throw http.ClientException('x')))));
      await fillLogin(t);
      await tapLogin(t);
      await t.pumpAndSettle();
      expect(find.textContaining('Cannot reach'), findsOneWidget);
    });

    testWidgets('success navigates to Home with name and role', (t) async {
      await t.pumpWidget(app(LoginScreen(
          authService: svc((_) async => json(200,
              {'token': 'T', 'user': userJson(name: 'Bob', role: 'PH')})))));
      await fillLogin(t);
      await tapLogin(t);
      await t.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Xin chào, Bob'), findsOneWidget);
      expect(find.text('Phụ huynh'), findsOneWidget);
    });

    testWidgets('loading indicator while pending; double tap sends one request',
        (t) async {
      final c = Completer<http.Response>();
      var calls = 0;
      await t.pumpWidget(app(LoginScreen(authService: svc((_) {
        calls++;
        return c.future;
      }))));
      await fillLogin(t);
      await tapLogin(t);
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(t.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull);
      await t.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await t.pump();
      expect(calls, 1);
      c.complete(json(200, {'token': 'T', 'user': userJson()}));
      await t.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('pressing done on password field submits once', (t) async {
      var calls = 0;
      await t.pumpWidget(app(LoginScreen(authService: svc((_) async {
        calls++;
        return json(200, {
          'token': 'x',
          'user': {'id': 1, 'name': 'Bob', 'role': 'PH'}
        });
      }))));
      await fillLogin(t);
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('eye icon toggles password visibility', (t) async {
      await t.pumpWidget(app(const LoginScreen()));
      bool obscured() => t
          .widget<TextField>(find.byType(TextField).at(1))
          .obscureText;
      expect(obscured(), isTrue);
      await t.tap(find.byIcon(Icons.visibility_off_outlined));
      await t.pump();
      expect(obscured(), isFalse);
    });

    testWidgets('remember checkbox toggles; no dead FEID button', (t) async {
      await t.pumpWidget(app(const LoginScreen()));
      expect(t.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      await t.tap(find.byType(Checkbox));
      await t.pump();
      expect(t.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(find.text('FEID'), findsNothing);
      expect(find.text('Hoặc đăng nhập bằng'), findsNothing);
    });

    testWidgets('no create-account button; forgot password opens reset screen',
        (t) async {
      await t.pumpWidget(app(const LoginScreen()));
      expect(find.text('Create new account'), findsNothing);
      await t.tap(find.text('Quên mật khẩu ?'));
      await t.pumpAndSettle();
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
    });
  });

  group('ResetPasswordScreen', () {
    Finder resetBtn() => find.widgetWithText(ElevatedButton, 'Reset password');
    Future<void> fill(WidgetTester t, String p, String c) async {
      await t.enterText(find.byType(TextFormField).at(0), '0901234567');
      await t.enterText(find.byType(TextFormField).at(1), p);
      await t.enterText(find.byType(TextFormField).at(2), c);
    }

    testWidgets('invalid phone and FPT logo', (t) async {
      await t.pumpWidget(app(
          ResetPasswordScreen(authService: svc((_) async => json(200, {})))));
      expect(find.byType(FptLogo), findsOneWidget);
      await t.enterText(find.byType(TextFormField).at(0), 'a@b.com');
      await t.ensureVisible(resetBtn());
      await t.tap(resetBtn());
      await t.pump();
      expect(find.text('Số điện thoại không hợp lệ'), findsOneWidget);
    });

    testWidgets('mismatch', (t) async {
      await t.pumpWidget(app(
          ResetPasswordScreen(authService: svc((_) async => json(200, {})))));
      await fill(t, 'abcdef', 'abcdeg');
      await t.ensureVisible(resetBtn());
      await t.tap(resetBtn());
      await t.pump();
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('too short', (t) async {
      await t.pumpWidget(app(
          ResetPasswordScreen(authService: svc((_) async => json(200, {})))));
      await fill(t, 'abc', 'abc');
      await t.ensureVisible(resetBtn());
      await t.tap(resetBtn());
      await t.pump();
      expect(
          find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('success shows message and returns to login', (t) async {
      await t.pumpWidget(app(LoginScreen(
          authService:
              svc((_) async => json(200, {'message': 'Password updated'})))));
      await t.tap(find.text('Quên mật khẩu ?'));
      await t.pumpAndSettle();
      await fill(t, 'abcdef', 'abcdef');
      await t.ensureVisible(resetBtn());
      await t.tap(resetBtn());
      await t.pumpAndSettle();
      expect(find.byType(ResetPasswordScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Password updated'), findsOneWidget);
    });

    testWidgets('server error shown inline', (t) async {
      await t.pumpWidget(app(ResetPasswordScreen(
          authService:
              svc((_) async => json(404, {'message': 'User not found'})))));
      await fill(t, 'abcdef', 'abcdef');
      await t.ensureVisible(resetBtn());
      await t.tap(resetBtn());
      await t.pumpAndSettle();
      expect(find.text('User not found'), findsOneWidget);
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
    });
  });

  group('HomeScreen', () {
    User u(String role) =>
        User(id: 1, name: 'N', email: 'e', phone: 'p', role: role);

    const all = ['Thời khóa biểu', 'Bảng điểm', 'Đơn từ', 'Câu lạc bộ'];
    const noGrade = ['Thời khóa biểu', 'Đơn từ', 'Câu lạc bộ'];
    const expected = {'GV': noGrade, 'Manager': noGrade, 'PH': all, 'HS': all};

    for (final role in ['GV', 'Manager', 'PH', 'HS']) {
      testWidgets('tiles for $role', (t) async {
        await t.pumpWidget(app(HomeScreen(user: u(role))));
        for (final l in all) {
          expect(find.text(l),
              expected[role]!.contains(l) ? findsOneWidget : findsNothing);
        }
        expect(find.text(roleName(role)), findsOneWidget);
        expect(find.byType(FptLogo), findsOneWidget);
        expect(tilesForRole(role), expected[role]);
      });
    }

    testWidgets('unknown role sees no tiles', (t) async {
      await t.pumpWidget(app(HomeScreen(user: u('X'))));
      expect(find.text('Thời khóa biểu'), findsNothing);
      expect(tilesForRole('X'), isEmpty);
    });

    testWidgets('logout clears session and returns to login', (t) async {
      Session.token = 'T';
      Session.user = u('GV');
      await t.pumpWidget(app(HomeScreen(user: u('GV'))));
      await t.tap(find.byIcon(Icons.logout));
      await t.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(Session.token, isNull);
      expect(Session.user, isNull);
    });
  });
}
