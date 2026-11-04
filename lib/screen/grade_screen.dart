import 'package:flutter/material.dart';

import '../models/school.dart';
import '../models/user.dart';
import '../services/school_service.dart';
import '../theme/app_theme.dart';
import 'grade_detail_screen.dart';
import 'student_picker.dart';
import 'widgets.dart';

/// 'HK1' -> 'học kỳ 1'.
String termLabel(String term) {
  final m = RegExp(r'^HK(\d)$').firstMatch(term);
  return m == null ? term : 'học kỳ ${m.group(1)}';
}

class _Data {
  const _Data(this.students, this.summary);
  final List<Student> students;
  final GradeSummary summary;
}

class GradeScreen extends StatefulWidget {
  const GradeScreen({super.key, required this.user, this.service});

  final User user;
  final SchoolService? service;

  @override
  State<GradeScreen> createState() => _GradeScreenState();
}

class _GradeScreenState extends State<GradeScreen> {
  late final SchoolService _svc = widget.service ?? SchoolService();
  late Future<_Data> _future = _load();
  int? _studentId;

  Future<_Data> _load() async {
    final students =
        widget.user.role == 'PH' ? await _svc.children() : <Student>[];
    if (_studentId == null && students.isNotEmpty) _studentId = students.first.id;
    return _Data(students, await _svc.grades(studentId: _studentId));
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _refresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bảng điểm')),
      body: FutureView<_Data>(
        future: _future,
        onRetry: _reload,
        builder: (context, data) {
          final g = data.summary;
          return RefreshList(
            onRefresh: _refresh,
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.gutter, Space.gutter, Space.xxl),
            children: [
              if (data.students.length > 1)
                StudentPicker(
                  students: data.students,
                  selectedId: _studentId!,
                  onChanged: (id) {
                    _studentId = id;
                    _reload();
                  },
                ),
              _summary(g),
              const SizedBox(height: Space.md + 2),
              const TableHeader(['Môn học', 'Giữa kỳ', 'Cuối kỳ', 'TB'],
                  flex: [4, 2, 2, 2]),
              if (g.subjects.isEmpty)
                const EmptyState(
                    icon: Icons.grade_outlined,
                    message: 'Chưa có điểm trong học kỳ này'),
              for (final s in g.subjects) _row(s),
              const SizedBox(height: Space.md),
              const ScoreLegend(),
              const SizedBox(height: Space.sm),
              Center(
                child: Text('Chạm vào môn học để xem chi tiết điểm',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summary(GradeSummary g) {
    final white = context.text.bodyMedium?.copyWith(color: Colors.white);
    final level = scoreLevel(g.average);
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
          color: AppColors.brandStrong,
          borderRadius: BorderRadius.circular(Radii.card)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Điểm trung bình ${termLabel(g.term)}', style: white),
                const SizedBox(height: Space.xs),
                Text(fmtScore(g.average, digits: 2),
                    key: const Key('overallAverage'),
                    style: context.text.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontFeatures: tabularFigures)),
                if (level != null)
                  Text(scoreLevelName(level),
                      style: white?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (g.rank != null)
                Text('Xếp loại: ${g.rank}',
                    style: white?.copyWith(fontWeight: FontWeight.w600)),
              if (g.conduct != null)
                Text('Hạnh kiểm: ${g.conduct}',
                    style: white?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(SubjectGrade s) {
    final style = context.text.bodyMedium?.copyWith(fontFeatures: tabularFigures);
    return Semantics(
      button: true,
      label: 'Môn ${s.subject}, giữa kỳ ${fmtScore(s.midterm)}, '
          'cuối kỳ ${fmtScore(s.finalExam)}, trung bình ${fmtScore(s.average)}',
      excludeSemantics: true,
      child: InkWell(
        key: Key('subject_${s.subject}'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GradeDetailScreen(
              subject: s.subject,
              studentId: _studentId,
              service: _svc,
            ),
          ),
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: Space.minTap + 4),
          padding: const EdgeInsets.symmetric(
              horizontal: Space.md, vertical: Space.sm),
          decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(flex: 4, child: Text(s.subject, style: style)),
            Expanded(
                flex: 2,
                child: Text(fmtScore(s.midterm),
                    textAlign: TextAlign.center, style: style)),
            Expanded(
                flex: 2,
                child: Text(fmtScore(s.finalExam),
                    textAlign: TextAlign.center, style: style)),
            Expanded(flex: 2, child: ScoreBadge(s.average)),
          ]),
        ),
      ),
    );
  }
}
