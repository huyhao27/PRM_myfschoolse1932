import 'package:flutter/material.dart';

import '../models/school.dart';
import '../services/school_service.dart';
import '../theme/app_theme.dart';
import 'grade_screen.dart' show termLabel;
import 'widgets.dart';

class GradeDetailScreen extends StatefulWidget {
  const GradeDetailScreen(
      {super.key, required this.subject, this.studentId, this.service});

  final String subject;
  final int? studentId;
  final SchoolService? service;

  @override
  State<GradeDetailScreen> createState() => _GradeDetailScreenState();
}

class _GradeDetailScreenState extends State<GradeDetailScreen> {
  late final SchoolService _svc = widget.service ?? SchoolService();
  late Future<GradeDetail> _future = _load();

  Future<GradeDetail> _load() =>
      _svc.gradeDetail(widget.subject, studentId: widget.studentId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Điểm môn ${widget.subject}')),
      body: FutureView<GradeDetail>(
        future: _future,
        onRetry: () => setState(() {
          _future = _load();
        }),
        builder: (context, d) {
          final white = context.text.bodyMedium?.copyWith(color: Colors.white);
          final level = scoreLevel(d.average);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.gutter, Space.gutter, Space.xxl),
            children: [
              Container(
                padding: const EdgeInsets.all(Space.lg),
                decoration: BoxDecoration(
                    color: AppColors.brandStrong,
                    borderRadius: BorderRadius.circular(Radii.card)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trung bình môn ${d.subject} - ${d.term}',
                              style: white),
                          const SizedBox(height: Space.xs),
                          Text(fmtScore(d.average),
                              key: const Key('subjectAverage'),
                              style: context.text.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: tabularFigures)),
                          if (level != null)
                            Text(scoreLevelName(level),
                                style: white?.copyWith(
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    if (d.teacherName != null)
                      Flexible(
                        child: Text('GV: ${d.teacherName}',
                            textAlign: TextAlign.end,
                            style:
                                white?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.md + 2),
              const TableHeader(['Loại điểm', 'Hệ số', 'Điểm', 'Ngày'],
                  flex: [4, 2, 2, 2]),
              for (final i in d.items) _row(i),
              const SizedBox(height: Space.md),
              const ScoreLegend(),
              if (d.comment != null && d.comment!.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                SectionCard('Nhận xét của giáo viên',
                    child: Text(d.comment!, style: context.text.bodyMedium)),
              ],
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  'Điểm của ${termLabel(d.term)}',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(GradeItem i) {
    final style = context.text.bodyMedium?.copyWith(fontFeatures: tabularFigures);
    return Container(
      constraints: const BoxConstraints(minHeight: Space.minTap),
      padding:
          const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(children: [
        Expanded(flex: 4, child: Text(i.type, style: style)),
        Expanded(
            flex: 2,
            child:
                Text('${i.weight}', textAlign: TextAlign.center, style: style)),
        Expanded(flex: 2, child: ScoreBadge(i.score)),
        Expanded(
            flex: 2,
            child: Text(fmtDay(i.date),
                textAlign: TextAlign.center,
                style: style?.copyWith(color: AppColors.muted))),
      ]),
    );
  }
}
