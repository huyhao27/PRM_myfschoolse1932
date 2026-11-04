// Plain data classes for the school features. Each one parses the backend JSON.

String _s(Object? v) => (v ?? '').toString();
int _i(Object? v) => v is num ? v.toInt() : 0;
double? _d(Object? v) => v is num ? v.toDouble() : null;
Map<String, dynamic> _m(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

class Student {
  const Student({required this.id, required this.name, required this.className});
  final int id;
  final String name;
  final String className;

  factory Student.fromJson(Map<String, dynamic> j) => Student(
      id: _i(j['id']), name: _s(j['name']), className: _s(j['className']));
}

class Lesson {
  const Lesson({
    required this.id,
    required this.dayOfWeek,
    required this.period,
    required this.subject,
    required this.className,
    required this.room,
    required this.startTime,
    required this.endTime,
    required this.teacherName,
    required this.mode,
    required this.content,
    required this.prep,
    required this.note,
  });
  final int id;
  final int dayOfWeek; // 1 = Monday ... 7 = Sunday
  final int period;
  final String subject;
  final String className;
  final String room;
  final String startTime;
  final String endTime;
  final String teacherName;
  final String mode;
  final String content;
  final String prep;
  final String note;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: _i(j['id']),
        dayOfWeek: _i(j['dayOfWeek']),
        period: _i(j['period']),
        subject: _s(j['subject']),
        className: _s(j['className']),
        room: _s(j['room']),
        startTime: _s(j['startTime']),
        endTime: _s(j['endTime']),
        teacherName: _s(j['teacherName']),
        mode: _s(j['mode']),
        content: _s(j['content']),
        prep: _s(j['prep']),
        note: _s(j['note']),
      );
}

class SubjectGrade {
  const SubjectGrade(
      {required this.subject, this.midterm, this.finalExam, this.average});
  final String subject;
  final double? midterm;
  final double? finalExam;
  final double? average;

  factory SubjectGrade.fromJson(Map<String, dynamic> j) => SubjectGrade(
        subject: _s(j['subject']),
        midterm: _d(j['midterm']),
        finalExam: _d(j['final']),
        average: _d(j['average']),
      );
}

class GradeSummary {
  const GradeSummary({
    required this.student,
    required this.term,
    required this.subjects,
    this.average,
    this.rank,
    this.conduct,
  });
  final Student student;
  final String term;
  final double? average;
  final String? rank;
  final String? conduct;
  final List<SubjectGrade> subjects;

  factory GradeSummary.fromJson(Map<String, dynamic> j) => GradeSummary(
        student: Student.fromJson(_m(j['student'])),
        term: _s(j['term']),
        average: _d(j['average']),
        rank: j['rank'] as String?,
        conduct: j['conduct'] as String?,
        subjects: [
          for (final x in (j['subjects'] as List? ?? []))
            SubjectGrade.fromJson(_m(x))
        ],
      );
}

class GradeItem {
  const GradeItem(
      {required this.type,
      required this.weight,
      required this.score,
      required this.date});
  final String type;
  final int weight;
  final double score;
  final String date; // yyyy-MM-dd

  factory GradeItem.fromJson(Map<String, dynamic> j) => GradeItem(
        type: _s(j['type']),
        weight: _i(j['weight']),
        score: _d(j['score']) ?? 0,
        date: _s(j['date']),
      );
}

class GradeDetail {
  const GradeDetail({
    required this.subject,
    required this.term,
    required this.items,
    this.average,
    this.teacherName,
    this.comment,
  });
  final String subject;
  final String term;
  final double? average;
  final String? teacherName;
  final String? comment;
  final List<GradeItem> items;

  factory GradeDetail.fromJson(Map<String, dynamic> j) => GradeDetail(
        subject: _s(j['subject']),
        term: _s(j['term']),
        average: _d(j['average']),
        teacherName: j['teacherName'] as String?,
        comment: j['comment'] as String?,
        items: [
          for (final x in (j['items'] as List? ?? [])) GradeItem.fromJson(_m(x))
        ],
      );
}

class RequestItem {
  const RequestItem({
    required this.id,
    required this.type,
    required this.status,
    required this.reason,
    required this.fromDate,
    required this.toDate,
    required this.createdAt,
    required this.student,
    required this.creatorName,
    required this.creatorRole,
    this.teacherComment,
    this.handledByName,
  });
  final int id;
  final String type;
  final String status; // pending | approved | rejected
  final String reason;
  final String fromDate; // yyyy-MM-dd or ''
  final String toDate;
  final String createdAt; // ISO, UTC
  final Student student;
  final String creatorName;
  final String creatorRole;
  final String? teacherComment;
  final String? handledByName;

  bool get isPending => status == 'pending';

  factory RequestItem.fromJson(Map<String, dynamic> j) {
    final creator = _m(j['creator']);
    return RequestItem(
      id: _i(j['id']),
      type: _s(j['type']),
      status: _s(j['status']),
      reason: _s(j['reason']),
      fromDate: _s(j['fromDate']),
      toDate: _s(j['toDate']),
      createdAt: _s(j['createdAt']),
      student: Student.fromJson(_m(j['student'])),
      creatorName: _s(creator['name']),
      creatorRole: _s(creator['role']),
      teacherComment: j['teacherComment'] as String?,
      handledByName: j['handledByName'] as String?,
    );
  }
}

class ClubItem {
  const ClubItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.memberCount,
    this.myStatus,
  });
  final int id;
  final String name;
  final String icon;
  final int memberCount;
  final String? myStatus; // null | pending | approved

  factory ClubItem.fromJson(Map<String, dynamic> j) => ClubItem(
        id: _i(j['id']),
        name: _s(j['name']),
        icon: _s(j['icon']),
        memberCount: _i(j['memberCount']),
        myStatus: j['myStatus'] as String?,
      );
}

class ClubDetail {
  const ClubDetail({
    required this.club,
    required this.description,
    required this.meeting,
    required this.location,
    required this.advisor,
    required this.president,
    required this.memberPreview,
  });
  final ClubItem club;
  final String description;
  final String meeting;
  final String location;
  final String advisor;
  final String president;
  final List<String> memberPreview;

  factory ClubDetail.fromJson(Map<String, dynamic> j) => ClubDetail(
        club: ClubItem.fromJson(j),
        description: _s(j['description']),
        meeting: _s(j['meeting']),
        location: _s(j['location']),
        advisor: _s(j['advisor']),
        president: _s(j['president']),
        memberPreview: [
          for (final x in (j['memberPreview'] as List? ?? [])) _s(x)
        ],
      );
}
