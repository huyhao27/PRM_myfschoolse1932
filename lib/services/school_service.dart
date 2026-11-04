import '../models/school.dart';
import 'api_client.dart';

/// All calls for schedule, grades, requests and clubs. Pass a custom
/// [ApiClient] (with a fake http client) in tests.
class SchoolService {
  SchoolService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Map<String, String>? _q(Map<String, String?> m) {
    final r = {
      for (final e in m.entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!
    };
    return r.isEmpty ? null : r;
  }

  Future<List<Student>> children() async => [
        for (final x in await _api.getList('/api/children'))
          Student.fromJson(Map<String, dynamic>.from(x as Map))
      ];

  Future<List<Lesson>> schedule({int? studentId}) async {
    final data = await _api.getMap('/api/schedule',
        query: _q({'studentId': studentId?.toString()}));
    return [
      for (final x in (data['items'] as List? ?? []))
        Lesson.fromJson(Map<String, dynamic>.from(x as Map))
    ];
  }

  Future<GradeSummary> grades({int? studentId}) async => GradeSummary.fromJson(
      await _api.getMap('/api/grades',
          query: _q({'studentId': studentId?.toString()})));

  Future<GradeDetail> gradeDetail(String subject, {int? studentId}) async =>
      GradeDetail.fromJson(await _api.getMap(
          '/api/grades/${Uri.encodeComponent(subject)}',
          query: _q({'studentId': studentId?.toString()})));

  Future<List<RequestItem>> requests() async => [
        for (final x in await _api.getList('/api/requests'))
          RequestItem.fromJson(Map<String, dynamic>.from(x as Map))
      ];

  Future<RequestItem> createRequest({
    required int studentId,
    required String type,
    required String fromDate,
    String? toDate,
    required String reason,
  }) async =>
      RequestItem.fromJson(await _api.post('/api/requests', {
        'studentId': studentId,
        'type': type,
        'fromDate': fromDate,
        'toDate': ?toDate,
        'reason': reason,
      }, auth: true));

  Future<RequestItem> decide(int id, String decision, String comment) async =>
      RequestItem.fromJson(await _api.post('/api/requests/$id/decision',
          {'decision': decision, 'comment': comment},
          auth: true));

  Future<List<ClubItem>> clubs() async => [
        for (final x in await _api.getList('/api/clubs'))
          ClubItem.fromJson(Map<String, dynamic>.from(x as Map))
      ];

  Future<ClubDetail> club(int id) async =>
      ClubDetail.fromJson(await _api.getMap('/api/clubs/$id'));

  Future<void> joinClub(int id) async {
    await _api.post('/api/clubs/$id/join', {}, auth: true);
  }
}
