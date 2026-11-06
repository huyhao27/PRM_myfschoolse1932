import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myfschoolse1932/models/user.dart';
import 'package:myfschoolse1932/screen/club_list_screen.dart';
import 'package:myfschoolse1932/screen/home_screen.dart';
import 'package:myfschoolse1932/screen/login_screen.dart';
import 'package:myfschoolse1932/screen/request_list_screen.dart';
import 'package:myfschoolse1932/screen/schedule_screen.dart';
import 'package:myfschoolse1932/screen/widgets.dart';
import 'package:myfschoolse1932/services/api_config.dart';
import 'package:myfschoolse1932/services/api_client.dart';
import 'package:myfschoolse1932/services/school_service.dart';
import 'package:myfschoolse1932/theme/app_theme.dart';

import 'helpers.dart';

Widget host(Widget child, {double scale = 1, bool reduceMotion = false}) =>
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduceMotion),
        child: c!,
      ),
      home: Scaffold(body: child),
    );

SchoolService fakeService(Map<String, Object> routes) => SchoolService(
      api: ApiClient(
        client: MockClient((req) async {
          final r = routes['${req.method} ${req.url.path}'];
          return r == null ? json(404, {'message': 'Not found'}) : json(200, r);
        }),
        baseUrl: 'http://test',
      ),
    );

const _student = {'id': 7, 'name': 'Nguyen Van An', 'className': '10A1'};

Map<String, dynamic> _lesson(int day, int period, String subject) => {
      'id': day * 10 + period,
      'dayOfWeek': day,
      'period': period,
      'subject': subject,
      'className': '10A1',
      'room': 'P.301',
      'startTime': '07:30',
      'endTime': '08:15',
      'teacherName': 'Co Lan',
      'mode': 'Trực tiếp',
      'content': '',
      'prep': '',
      'note': '',
    };

void main() {
  setUp(Session.clear);

  group('StatusBadge', () {
    testWidgets('every status has an icon and a label', (t) async {
      await t.pumpWidget(host(Column(children: [
        StatusBadge.request('pending'),
        StatusBadge.request('approved'),
        StatusBadge.request('rejected'),
      ])));
      for (final (label, icon) in [
        ('Chờ duyệt', Icons.hourglass_empty),
        ('Đã duyệt', Icons.check_circle_outline),
        ('Từ chối', Icons.highlight_off),
      ]) {
        final badge = find.ancestor(
            of: find.text(label), matching: find.byType(StatusBadge));
        expect(badge, findsOneWidget, reason: label);
        expect(
            find.descendant(of: badge, matching: find.byIcon(icon)),
            findsOneWidget,
            reason: label);
      }
    });
  });

  group('EmptyState', () {
    testWidgets('shows message and runs the action', (t) async {
      var taps = 0;
      await t.pumpWidget(host(EmptyState(
          icon: Icons.inbox,
          message: 'Chưa có gì',
          actionLabel: 'Tạo đơn',
          onAction: () => taps++)));
      expect(find.text('Chưa có gì'), findsOneWidget);
      await t.tap(find.byKey(const Key('emptyAction')));
      expect(taps, 1);
    });

    testWidgets('no action button without a label', (t) async {
      await t.pumpWidget(
          host(const EmptyState(icon: Icons.inbox, message: 'Trống')));
      expect(find.byKey(const Key('emptyAction')), findsNothing);
    });
  });

  group('FutureView', () {
    testWidgets('skeleton while loading, then data', (t) async {
      final c = Completer<String>();
      await t.pumpWidget(host(FutureView<String>(
          future: c.future,
          onRetry: () {},
          builder: (_, d) => Text(d))));
      expect(find.byKey(const Key('skeleton')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      c.complete('xong');
      await t.pumpAndSettle();
      expect(find.text('xong'), findsOneWidget);
      expect(find.byKey(const Key('skeleton')), findsNothing);
    });

    testWidgets('error shows loadError and retry calls back', (t) async {
      var retries = 0;
      await t.pumpWidget(host(FutureView<String>(
          future: Future<String>.delayed(
              Duration.zero, () => throw AuthException('Lỗi mạng')),
          onRetry: () => retries++,
          builder: (_, d) => Text(d))));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('loadError')), findsOneWidget);
      expect(find.text('Lỗi mạng'), findsOneWidget);
      await t.tap(find.text('Thử lại'));
      expect(retries, 1);
    });

    testWidgets('skeleton pulses normally but is still with reduced motion',
        (t) async {
      final never = Completer<String>().future;
      Widget view() => FutureView<String>(
          future: never, onRetry: () {}, builder: (_, d) => Text(d));

      double opacity() =>
          t.widget<Opacity>(find.descendant(
                  of: find.byType(SkeletonList),
                  matching: find.byType(Opacity)))
              .opacity;

      await t.pumpWidget(host(view()));
      await t.pump(const Duration(milliseconds: 450));
      expect(opacity(), lessThan(1));

      await t.pumpWidget(host(view(), reduceMotion: true));
      await t.pump();
      // With reduced motion nothing keeps scheduling frames.
      await t.pumpAndSettle();
      expect(opacity(), 1);
    });
  });

  group('Club icons', () {
    test('seed glyphs map to Material icons', () {
      expect(clubIconData('</>'), Icons.code);
      expect(clubIconData('⚽'), Icons.sports_soccer);
      expect(clubIconData('♪'), Icons.music_note);
      expect(clubIconData('✎'), Icons.brush);
      expect(clubIconData('●'), Icons.sports_basketball);
      expect(clubIconData('X'), isNull);
    });

    testWidgets('avatar draws an icon for known keys and text otherwise',
        (t) async {
      await t.pumpWidget(host(const Row(children: [
        ClubAvatar('⚽'),
        ClubAvatar('LQ'),
      ])));
      expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
      expect(find.text('⚽'), findsNothing);
      expect(find.text('LQ'), findsOneWidget);
    });

    test('membership badges', () {
      expect(membershipBadge('approved', canJoin: true)!.kind,
          StatusKind.approved);
      expect(
          membershipBadge('pending', canJoin: false)!.kind, StatusKind.pending);
      expect(membershipBadge(null, canJoin: true)!.label, 'Tham gia');
      expect(membershipBadge(null, canJoin: false), isNull);
    });
  });

  group('Schedule today highlight', () {
    final svc = fakeService({
      'GET ${ApiConfig.prefix}/schedule': {
        'className': '10A1',
        'items': [_lesson(3, 1, 'Anh'), _lesson(1, 1, 'Toán')],
      },
    });
    final clock = DateTime(2026, 10, 14, 9); // Wednesday

    Color? cellColor(WidgetTester t, String key) => t
        .widget<Material>(find
            .ancestor(of: find.byKey(Key(key)), matching: find.byType(Material))
            .first)
        .color;

    testWidgets("today's lesson cell is tinted; other days are not",
        (t) async {
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: ScheduleScreen(
              user: User(id: 1, name: 'A', email: '', phone: '', role: 'HS'),
              service: svc,
              clock: () => clock)));
      await t.pumpAndSettle();
      expect(cellColor(t, 'lesson_3_1'), AppColors.brandSoft);
      expect(cellColor(t, 'lesson_1_1'), AppColors.surface);
      expect(find.bySemanticsLabel('Tiết 1 Thứ Tư Anh, hôm nay'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Tiết 1 Thứ Hai Toán'), findsOneWidget);

      // Another week has no "today".
      await t.tap(find.byKey(const Key('nextWeek')));
      await t.pump();
      expect(cellColor(t, 'lesson_3_1'), AppColors.surface);
    });

    testWidgets('week arrows have accessible names', (t) async {
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: ScheduleScreen(
              user: User(id: 1, name: 'A', email: '', phone: '', role: 'HS'),
              service: svc,
              clock: () => clock)));
      await t.pumpAndSettle();
      expect(find.byTooltip('Tuần trước'), findsOneWidget);
      expect(find.byTooltip('Tuần sau'), findsOneWidget);
    });
  });

  group('Score levels', () {
    test('thresholds', () {
      expect(scoreLevel(null), isNull);
      expect(scoreLevel(8), ScoreLevel.excellent);
      expect(scoreLevel(7.99), ScoreLevel.good);
      expect(scoreLevel(6.5), ScoreLevel.good);
      expect(scoreLevel(6.49), ScoreLevel.fair);
      expect(scoreLevel(5), ScoreLevel.fair);
      expect(scoreLevel(4.9), ScoreLevel.weak);
    });

    testWidgets('badge uses the level colour and the level name for readers',
        (t) async {
      await t.pumpWidget(host(const Column(children: [
        ScoreBadge(9),
        ScoreBadge(7),
        ScoreBadge(5.5),
        ScoreBadge(3),
      ])));
      Color bg(String text) => ((t
                  .widget<Container>(find
                      .ancestor(
                          of: find.text(text), matching: find.byType(Container))
                      .first)
                  .decoration) as BoxDecoration)
              .color!;
      expect(bg('9.0'), AppColors.successSoft);
      expect(bg('7.0'), AppColors.infoSoft);
      expect(bg('5.5'), AppColors.warningSoft);
      expect(bg('3.0'), AppColors.dangerSoft);
      expect(find.bySemanticsLabel('9.0, Giỏi'), findsOneWidget);
      expect(find.bySemanticsLabel('3.0, Yếu'), findsOneWidget);
    });
  });

  group('Text scale 1.3 at 360x640', () {
    Future<void> phone(WidgetTester t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    Widget scaled(Widget home) => MaterialApp(
          theme: AppTheme.light,
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: c!,
          ),
          home: home,
        );

    testWidgets('login', (t) async {
      await phone(t);
      await t.pumpWidget(scaled(const LoginScreen()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('home', (t) async {
      await phone(t);
      await t.pumpWidget(scaled(HomeScreen(
          user: User(
              id: 1, name: 'Nguyen Van Binh', email: '', phone: '', role: 'PH'))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Phụ huynh'), findsOneWidget);
    });

    testWidgets('request list with cards and filters', (t) async {
      await phone(t);
      final svc = fakeService({
        'GET ${ApiConfig.prefix}/requests': [
          {
            'id': 1,
            'type': 'Xin nghỉ học',
            'status': 'pending',
            'reason': 'Con bị sốt cao phải đi khám',
            'fromDate': '2026-10-15',
            'toDate': '2026-10-16',
            'createdAt': '2026-10-14T13:15:00',
            'student': _student,
            'creator': {'name': 'Binh', 'role': 'PH'},
          },
        ],
      });
      await t.pumpWidget(scaled(RequestListScreen(
          user: User(id: 1, name: 'A', email: '', phone: '', role: 'PH'),
          service: svc)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Nghỉ 15/10 - 16/10/2026'), findsOneWidget);
    });

    testWidgets('empty request list offers to create one', (t) async {
      await phone(t);
      await t.pumpWidget(scaled(RequestListScreen(
          user: User(id: 1, name: 'A', email: '', phone: '', role: 'HS'),
          service: fakeService({'GET ${ApiConfig.prefix}/requests': <Object>[]}))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Chưa có đơn nào'), findsOneWidget);
      expect(find.byKey(const Key('emptyAction')), findsOneWidget);
      expect(find.byTooltip('Tạo đơn mới'), findsOneWidget);
    });
  });

  group('Login polish', () {
    testWidgets('password toggle has a tooltip and the error has an icon',
        (t) async {
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: LoginScreen(
              authService: svc((_) async =>
                  http.Response('{"message":"Invalid credentials"}', 401,
                      headers: {'content-type': 'application/json'})))));
      expect(find.byTooltip('Hiện mật khẩu'), findsOneWidget);
      await t.tap(find.byTooltip('Hiện mật khẩu'));
      await t.pump();
      expect(find.byTooltip('Ẩn mật khẩu'), findsOneWidget);

      await t.enterText(find.byType(TextFormField).at(0), '0901234567');
      await t.enterText(find.byType(TextFormField).at(1), 'secret1');
      await t.ensureVisible(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await t.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await t.pumpAndSettle();
      final error = find.ancestor(
          of: find.byKey(const Key('loginError')),
          matching: find.byType(InlineError));
      expect(error, findsOneWidget);
      expect(find.descendant(of: error, matching: find.byIcon(Icons.error_outline)),
          findsOneWidget);
    });
  });
}
