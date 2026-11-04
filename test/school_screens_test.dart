import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myfschoolse1932/models/user.dart';
import 'package:myfschoolse1932/screen/club_detail_screen.dart';
import 'package:myfschoolse1932/screen/club_list_screen.dart';
import 'package:myfschoolse1932/screen/grade_screen.dart';
import 'package:myfschoolse1932/screen/home_screen.dart';
import 'package:myfschoolse1932/screen/request_list_screen.dart';
import 'package:myfschoolse1932/screen/schedule_screen.dart';
import 'package:myfschoolse1932/services/api_client.dart';
import 'package:myfschoolse1932/services/school_service.dart';
import 'package:myfschoolse1932/theme/app_theme.dart';

import 'helpers.dart';

User user(String role) =>
    User(id: 1, name: 'An', email: 'a@b.vn', phone: '', role: role);

/// A fake backend: routes by "METHOD path" and records every request.
class Fake {
  final Map<String, Object> routes;
  final List<http.Request> calls = [];
  Fake(this.routes);

  SchoolService get service => SchoolService(
        api: ApiClient(
          client: MockClient((req) async {
            calls.add(req);
            final key = '${req.method} ${req.url.path}';
            final r = routes[key];
            if (r == null) return json(404, {'message': 'Not found'});
            if (r is http.Response) return r;
            return json(200, r);
          }),
          baseUrl: 'http://test',
        ),
      );

  Map<String, dynamic> body(int i) => jsonDecode(calls[i].body);
}

Widget app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

const student = {'id': 7, 'name': 'Nguyen Van An', 'className': '10A1'};
const student2 = {'id': 8, 'name': 'Tran Thi Mai', 'className': '10A1'};

Map<String, dynamic> lesson(int day, int period, String subject,
        {String note = ''}) =>
    {
      'id': day * 10 + period,
      'dayOfWeek': day,
      'period': period,
      'subject': subject,
      'className': '10A1',
      'room': 'P.30$period',
      'startTime': '07:30',
      'endTime': '08:15',
      'teacherName': 'Co Lan',
      'mode': 'Trực tiếp',
      'content': 'Unit 4',
      'prep': 'Sach',
      'note': note,
    };

Map<String, dynamic> req(int id, String status, {String type = 'Xin nghỉ học'}) =>
    {
      'id': id,
      'type': type,
      'status': status,
      'reason': 'Con bị sốt',
      'fromDate': '2026-10-15',
      'toDate': '2026-10-16',
      'createdAt': '2026-10-14T13:15:00',
      'student': student,
      'creator': {'name': 'Binh', 'role': 'PH'},
      'teacherComment': status == 'pending' ? null : 'Đồng ý',
      'handledByName': status == 'pending' ? null : 'Co Lan',
      'handledAt': null,
    };

Map<String, dynamic> club(int id, String name, {String? my, int n = 10}) => {
      'id': id,
      'name': name,
      'icon': 'X',
      'memberCount': n,
      'myStatus': my,
    };

void main() {
  setUp(Session.clear);

  group('ScheduleScreen', () {
    final routes = <String, Object>{
      'GET /api/schedule': {
        'className': '10A1',
        'items': [
          lesson(3, 1, 'Anh', note: 'Kiểm tra 15 phút'),
          lesson(3, 2, 'Văn'),
          lesson(1, 1, 'Toán'),
        ],
      },
    };
    // Wednesday 14/10/2026.
    DateTime clock() => DateTime(2026, 10, 14, 9);

    testWidgets('grid, week label and today card', (t) async {
      final f = Fake(routes);
      await t.pumpWidget(app(ScheduleScreen(
          user: user('HS'), service: f.service, clock: clock)));
      await t.pumpAndSettle();
      expect(find.text('Tuần 6: 12/10 - 17/10/2026'), findsOneWidget);
      expect(find.text('Toán'), findsOneWidget);
      expect(find.text('Hôm nay - Thứ Tư'), findsOneWidget);
      expect(find.text('Tiết 1: Anh - P.301 - Co Lan'), findsOneWidget);
      expect(find.text('Tiết 2: Văn - P.302 - Co Lan'), findsOneWidget);
    });

    testWidgets('week arrows move the week', (t) async {
      await t.pumpWidget(app(ScheduleScreen(
          user: user('HS'), service: Fake(routes).service, clock: clock)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('nextWeek')));
      await t.pump();
      expect(find.text('Tuần 7: 19/10 - 24/10/2026'), findsOneWidget);
      await t.tap(find.byKey(const Key('prevWeek')));
      await t.tap(find.byKey(const Key('prevWeek')));
      await t.pump();
      expect(find.text('Tuần 5: 05/10 - 10/10/2026'), findsOneWidget);
    });

    testWidgets('tapping a lesson opens its detail with the date', (t) async {
      await t.pumpWidget(app(ScheduleScreen(
          user: user('HS'), service: Fake(routes).service, clock: clock)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('lesson_3_1')));
      await t.pumpAndSettle();
      expect(find.text('Chi tiết tiết học'), findsOneWidget);
      expect(find.text('Thứ Tư, 14/10/2026 - Tiết 1 (07:30 - 08:15)'),
          findsOneWidget);
      expect(find.text('Kiểm tra 15 phút'), findsOneWidget);
      expect(find.text('Co Lan'), findsOneWidget);
    });

    testWidgets('parent with two children can switch student', (t) async {
      final f = Fake({
        ...routes,
        'GET /api/children': [student, student2],
      });
      await t.pumpWidget(app(
          ScheduleScreen(user: user('PH'), service: f.service, clock: clock)));
      await t.pumpAndSettle();
      expect(f.calls.last.url.queryParameters['studentId'], '7');
      await t.tap(find.byKey(const Key('studentPicker')));
      await t.pumpAndSettle();
      await t.tap(find.text('Tran Thi Mai - 10A1').last);
      await t.pumpAndSettle();
      expect(f.calls.last.url.queryParameters['studentId'], '8');
    });

    testWidgets('server error shows message and retry works', (t) async {
      var fail = true;
      final svc = SchoolService(
        api: ApiClient(
          client: MockClient((r) async => fail
              ? json(500, {})
              : json(200, {'className': '10A1', 'items': []})),
          baseUrl: 'http://test',
        ),
      );
      await t.pumpWidget(
          app(ScheduleScreen(user: user('HS'), service: svc, clock: clock)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('loadError')), findsOneWidget);
      fail = false;
      await t.tap(find.text('Thử lại'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('loadError')), findsNothing);
      expect(find.text('Hôm nay không có tiết học'), findsOneWidget);
    });
  });

  group('GradeScreen', () {
    final routes = <String, Object>{
      'GET /api/grades': {
        'student': student,
        'term': 'HK1',
        'average': 8.42,
        'rank': 'Giỏi',
        'conduct': 'Tốt',
        'subjects': [
          {'subject': 'Toán', 'midterm': 9, 'final': 9.0, 'average': 8.85},
          {'subject': 'Văn', 'midterm': 7.5, 'final': 8, 'average': 7.8},
        ],
      },
      'GET /api/grades/To%C3%A1n': {
        'student': student,
        'term': 'HK1',
        'subject': 'Toán',
        'average': 8.85,
        'teacherName': 'Thầy Bảo',
        'comment': 'Em tiếp thu tốt',
        'items': [
          {'type': 'Miệng', 'weight': 1, 'score': 9, 'date': '2026-09-10'},
          {'type': 'Cuối kỳ', 'weight': 3, 'score': 9, 'date': '2026-12-20'},
        ],
      },
    };

    testWidgets('summary then subject detail', (t) async {
      await t.pumpWidget(
          app(GradeScreen(user: user('HS'), service: Fake(routes).service)));
      await t.pumpAndSettle();
      expect(find.text('Điểm trung bình học kỳ 1'), findsOneWidget);
      expect(find.byKey(const Key('overallAverage')), findsOneWidget);
      expect(find.text('8.42'), findsOneWidget);
      expect(find.text('Xếp loại: Giỏi'), findsOneWidget);
      expect(find.text('Hạnh kiểm: Tốt'), findsOneWidget);
      expect(find.text('8.8'), findsOneWidget); // 8.85 shown with 1 digit
      await t.tap(find.byKey(const Key('subject_Toán')));
      await t.pumpAndSettle();
      expect(find.text('Điểm môn Toán'), findsOneWidget);
      expect(find.text('GV: Thầy Bảo'), findsOneWidget);
      expect(find.text('Em tiếp thu tốt'), findsOneWidget);
      expect(find.text('10/09'), findsOneWidget);
      expect(find.text('20/12'), findsOneWidget);
    });

    testWidgets('no grades shows an empty message', (t) async {
      final f = Fake({
        'GET /api/grades': {
          'student': student,
          'term': 'HK1',
          'average': null,
          'rank': null,
          'conduct': null,
          'subjects': [],
        },
      });
      await t.pumpWidget(app(GradeScreen(user: user('HS'), service: f.service)));
      await t.pumpAndSettle();
      expect(find.text('Chưa có điểm trong học kỳ này'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
    });
  });

  group('Requests', () {
    final list = [
      req(1, 'pending'),
      req(2, 'approved'),
      req(3, 'rejected', type: 'Xin đổi chỗ ngồi'),
    ];

    testWidgets('list, status filter and date text', (t) async {
      await t.pumpWidget(app(RequestListScreen(
          user: user('PH'), service: Fake({'GET /api/requests': list}).service)));
      await t.pumpAndSettle();
      expect(find.text('Xin nghỉ học'), findsNWidgets(2));
      expect(find.text('Nghỉ 15/10 - 16/10/2026'), findsNWidgets(2));
      expect(find.text('Ngày 15/10/2026'), findsOneWidget);
      await t.tap(find.byKey(const Key('filter_pending')));
      await t.pump();
      expect(find.text('Xin nghỉ học'), findsOneWidget);
      expect(find.text('Xin đổi chỗ ngồi'), findsNothing);
    });

    testWidgets('only PH and HS get the add button', (t) async {
      final svc = Fake({'GET /api/requests': list}).service;
      await t.pumpWidget(
          app(RequestListScreen(user: user('GV'), service: svc)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('addRequest')), findsNothing);
      await t.pumpWidget(
          app(RequestListScreen(user: user('HS'), service: svc)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('addRequest')), findsOneWidget);
    });

    testWidgets('teacher approves a pending request', (t) async {
      final f = Fake({
        'GET /api/requests': list,
        'POST /api/requests/1/decision': req(1, 'approved'),
      });
      await t.pumpWidget(
          app(RequestListScreen(user: user('GV'), service: f.service)));
      await t.pumpAndSettle();
      await t.tap(find.text('Chờ duyệt').last); // chip of the pending card
      await t.pumpAndSettle();
      expect(find.text('Chi tiết đơn'), findsOneWidget);
      await t.enterText(find.byKey(const Key('commentField')), 'Ok');
      await t.tap(find.widgetWithText(ElevatedButton, 'Duyệt'));
      await t.pumpAndSettle();
      final post = f.calls.firstWhere((c) => c.method == 'POST');
      expect(jsonDecode(post.body), {'decision': 'approved', 'comment': 'Ok'});
      expect(find.text('Chi tiết đơn'), findsNothing); // back on the list
    });

    testWidgets('decision error is shown and the screen stays', (t) async {
      final f = Fake({
        'GET /api/requests': list,
        'POST /api/requests/1/decision':
            json(409, {'message': 'Request was already handled'}),
      });
      await t.pumpWidget(
          app(RequestListScreen(user: user('GV'), service: f.service)));
      await t.pumpAndSettle();
      await t.tap(find.text('Chờ duyệt').last);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ElevatedButton, 'Từ chối'));
      await t.pumpAndSettle();
      expect(find.text('Request was already handled'), findsOneWidget);
      expect(find.text('Chi tiết đơn'), findsOneWidget);
    });

    testWidgets('decided request shows the teacher comment, no buttons',
        (t) async {
      await t.pumpWidget(app(RequestListScreen(
          user: user('GV'), service: Fake({'GET /api/requests': list}).service)));
      await t.pumpAndSettle();
      await t.tap(find.text('Đã duyệt').last);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('teacherComment')), findsOneWidget);
      expect(find.text('Đồng ý'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Duyệt'), findsNothing);
    });

    testWidgets('create: reason is required, then it posts and returns',
        (t) async {
      final f = Fake({
        'GET /api/requests': list,
        'GET /api/children': [student],
        'POST /api/requests': req(9, 'pending'),
      });
      await t.pumpWidget(
          app(RequestListScreen(user: user('HS'), service: f.service)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('addRequest')));
      await t.pumpAndSettle();
      expect(find.text('Tạo đơn mới'), findsOneWidget);

      await t.tap(find.widgetWithText(ElevatedButton, 'Gửi đơn'));
      await t.pump();
      expect(find.text('Vui lòng nhập lý do'), findsOneWidget);
      expect(f.calls.where((c) => c.method == 'POST'), isEmpty);

      await t.enterText(find.byKey(const Key('reasonField')), 'Bị ốm');
      await t.tap(find.widgetWithText(ElevatedButton, 'Gửi đơn'));
      await t.pumpAndSettle();
      final post = f.calls.firstWhere((c) => c.method == 'POST');
      final body = jsonDecode(post.body) as Map;
      expect(body['studentId'], 7);
      expect(body['type'], 'Xin nghỉ học');
      expect(body['reason'], 'Bị ốm');
      expect(body['fromDate'], matches(r'^\d{4}-\d{2}-\d{2}$'));
      expect(find.text('Tạo đơn mới'), findsNothing);
    });
  });

  group('Clubs', () {
    final list = [
      club(1, 'CLB Bóng đá', my: 'approved', n: 42),
      club(2, 'CLB Âm nhạc', my: 'pending'),
      club(3, 'CLB Lập trình', n: 56),
    ];
    final detail = {
      ...club(3, 'CLB Lập trình', n: 56),
      'description': 'Học Python',
      'meeting': 'Sinh hoạt T6, 15:30',
      'location': 'P.401',
      'advisor': 'Thầy Hùng',
      'president': 'Quân',
      'memberPreview': ['Le Van Quan', 'Mai Phuong'],
    };

    testWidgets('list shows membership chips; search filters', (t) async {
      await t.pumpWidget(app(ClubListScreen(
          user: user('HS'), service: Fake({'GET /api/clubs': list}).service)));
      await t.pumpAndSettle();
      expect(find.text('42 thành viên'), findsOneWidget);
      expect(find.text('Đã tham gia'), findsOneWidget);
      expect(find.text('Chờ duyệt'), findsOneWidget);
      expect(find.text('Tham gia'), findsOneWidget);
      await t.enterText(find.byKey(const Key('clubSearch')), 'lập');
      await t.pump();
      expect(find.text('CLB Lập trình'), findsOneWidget);
      expect(find.text('CLB Bóng đá'), findsNothing);
      await t.enterText(find.byKey(const Key('clubSearch')), 'zzz');
      await t.pump();
      expect(find.text('Không tìm thấy câu lạc bộ nào'), findsOneWidget);
    });

    testWidgets('non-students do not see the join chip', (t) async {
      await t.pumpWidget(app(ClubListScreen(
          user: user('PH'), service: Fake({'GET /api/clubs': list}).service)));
      await t.pumpAndSettle();
      expect(find.text('Tham gia'), findsNothing);
    });

    testWidgets('detail then join refreshes to pending', (t) async {
      var joined = false;
      final svc = SchoolService(
        api: ApiClient(
          client: MockClient((r) async {
            final key = '${r.method} ${r.url.path}';
            if (key == 'GET /api/clubs') return json(200, list);
            if (key == 'POST /api/clubs/3/join') {
              joined = true;
              return json(201, {'status': 'pending'});
            }
            if (key == 'GET /api/clubs/3') {
              return json(200, {...detail, 'myStatus': joined ? 'pending' : null});
            }
            return json(404, {'message': 'Not found'});
          }),
          baseUrl: 'http://test',
        ),
      );
      await t.pumpWidget(app(ClubListScreen(user: user('HS'), service: svc)));
      await t.pumpAndSettle();
      await t.tap(find.text('CLB Lập trình'));
      await t.pumpAndSettle();
      expect(find.text('Thầy Hùng'), findsOneWidget);
      expect(find.text('LQ'), findsOneWidget); // initials of Le Van Quan
      expect(find.text('+54'), findsOneWidget);
      await t.tap(find.widgetWithText(ElevatedButton, 'Tham gia câu lạc bộ'));
      await t.pumpAndSettle();
      expect(joined, isTrue);
      expect(find.text('Đang chờ duyệt'), findsOneWidget);
    });

    testWidgets('join conflict shows the server message', (t) async {
      final f = Fake({
        'GET /api/clubs/3': detail,
        'POST /api/clubs/3/join':
            json(409, {'message': 'You already joined or requested this club'}),
      });
      await t.pumpWidget(app(ClubDetailScreen(user: user('HS'), clubId: 3, service: f.service)));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ElevatedButton, 'Tham gia câu lạc bộ'));
      await t.pumpAndSettle();
      expect(find.text('You already joined or requested this club'),
          findsOneWidget);
    });
  });

  group('Home navigation', () {
    testWidgets('tiles open the right screens', (t) async {
      final f = Fake({
        'GET /api/schedule': {'className': '10A1', 'items': []},
        'GET /api/grades': {
          'student': student,
          'term': 'HK1',
          'average': null,
          'rank': null,
          'conduct': null,
          'subjects': [],
        },
        'GET /api/requests': <Object>[],
        'GET /api/clubs': <Object>[],
      });
      for (final (key, title) in [
        ('tile_Schedule', 'Thời khóa biểu'),
        ('tile_Grade', 'Bảng điểm'),
        ('tile_Request', 'Đơn từ'),
        ('tile_Club', 'Câu lạc bộ'),
      ]) {
        await t.pumpWidget(MaterialApp(
            key: UniqueKey(),
            theme: AppTheme.light,
            home: HomeScreen(user: user('HS'), service: f.service)));
        await t.tap(find.byKey(Key(key)));
        await t.pumpAndSettle();
        expect(find.descendant(of: find.byType(AppBar), matching: find.text(title)),
            findsOneWidget,
            reason: key);
      }
    });
  });
}
