import 'package:flutter/material.dart';

import '../models/school.dart';
import '../models/user.dart';
import '../services/school_service.dart';
import '../theme/app_theme.dart';
import 'schedule_detail_screen.dart';
import 'student_picker.dart';
import 'widgets.dart';

const weekdayNames = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];

// First Monday of the school year; week numbers count from here.
final _yearStart = DateTime(2026, 9, 7);

const _periodColWidth = 28.0;

class _Data {
  const _Data(this.students, this.lessons);
  final List<Student> students;
  final List<Lesson> lessons;
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen(
      {super.key, required this.user, this.service, this.clock});

  final User user;
  final SchoolService? service;

  /// Current time; injectable for tests.
  final DateTime Function()? clock;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final SchoolService _svc = widget.service ?? SchoolService();
  late Future<_Data> _future = _load();
  int _weekOffset = 0;
  int? _studentId;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  Future<_Data> _load() async {
    final students =
        widget.user.role == 'PH' ? await _svc.children() : <Student>[];
    if (_studentId == null && students.isNotEmpty) _studentId = students.first.id;
    final lessons = await _svc.schedule(studentId: _studentId);
    return _Data(students, lessons);
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

  DateTime get _monday {
    final n = _now;
    final today = DateTime(n.year, n.month, n.day);
    return today.add(Duration(days: -(today.weekday - 1) + 7 * _weekOffset));
  }

  String _dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thời khóa biểu')),
      body: FutureView<_Data>(
        future: _future,
        onRetry: _reload,
        builder: (context, data) => RefreshList(
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
            _weekBar(),
            const SizedBox(height: Space.sm),
            _grid(data.lessons),
            const SizedBox(height: Space.lg),
            _today(data.lessons),
            const SizedBox(height: Space.sm),
            Center(
              child: Text('Chạm vào ô tiết học để xem chi tiết',
                  textAlign: TextAlign.center, style: context.text.bodySmall),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekBar() {
    final mon = _monday;
    final sat = mon.add(const Duration(days: 5));
    final weekNo = ((mon.difference(_yearStart).inDays) ~/ 7 + 1).clamp(1, 99);
    return Row(
      children: [
        IconButton(
          key: const Key('prevWeek'),
          tooltip: 'Tuần trước',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() => _weekOffset--),
        ),
        Expanded(
          child: Text(
            'Tuần $weekNo: ${_dm(mon)} - ${_dm(sat)}/${sat.year}',
            key: const Key('weekLabel'),
            textAlign: TextAlign.center,
            style: context.text.titleSmall,
          ),
        ),
        IconButton(
          key: const Key('nextWeek'),
          tooltip: 'Tuần sau',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => setState(() => _weekOffset++),
        ),
      ],
    );
  }

  /// Day-of-week (1 = Monday) highlighted as today, only in the current week.
  int? get _todayColumn => _weekOffset == 0 ? _now.weekday : null;

  Widget _grid(List<Lesson> lessons) {
    final byCell = {for (final l in lessons) '${l.dayOfWeek}-${l.period}': l};
    final periods = lessons.isEmpty
        ? 5
        : lessons.map((l) => l.period).reduce((a, b) => a > b ? a : b).clamp(5, 12);
    const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    final mon = _monday;
    final today = _todayColumn;
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(Radii.control)),
          child: Row(children: [
            SizedBox(
                width: _periodColWidth,
                child: _Head('Tiết', null, highlight: false)),
            for (var d = 1; d <= 6; d++)
              Expanded(
                child: _Head(days[d - 1], _dm(mon.add(Duration(days: d - 1))),
                    highlight: d == today),
              ),
          ]),
        ),
        for (var p = 1; p <= periods; p++)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs + 2),
            child: Row(children: [
              SizedBox(
                  width: _periodColWidth,
                  child: Center(
                      child: Text('$p',
                          style: context.text.labelMedium
                              ?.copyWith(color: AppColors.muted)))),
              for (var d = 1; d <= 6; d++)
                Expanded(child: _lessonCell(byCell['$d-$p'], d == today)),
            ]),
          ),
      ],
    );
  }

  Widget _lessonCell(Lesson? l, bool isToday) {
    const minHeight = 48.0;
    if (l == null) {
      return Container(
        height: minHeight,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
            color: isToday ? AppColors.brandSoft.withValues(alpha: 0.5) : null,
            borderRadius: BorderRadius.circular(Radii.control)),
      );
    }
    final radius = BorderRadius.circular(Radii.control);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Semantics(
        button: true,
        label: 'Tiết ${l.period} ${weekdayNames[l.dayOfWeek - 1]} ${l.subject}'
            '${isToday ? ', hôm nay' : ''}',
        excludeSemantics: true,
        child: Material(
          color: isToday ? AppColors.brandSoft : AppColors.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(
                color: isToday ? AppColors.brandStrong : AppColors.line,
                width: isToday ? 1.5 : 1),
            borderRadius: radius,
          ),
          child: InkWell(
            key: Key('lesson_${l.dayOfWeek}_${l.period}'),
            borderRadius: radius,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScheduleDetailScreen(
                  lesson: l,
                  date: _monday.add(Duration(days: l.dayOfWeek - 1)),
                ),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: minHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(l.subject,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium
                          ?.copyWith(height: 1.2)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _today(List<Lesson> lessons) {
    final wd = _now.weekday;
    final todays = lessons.where((l) => l.dayOfWeek == wd).toList()
      ..sort((a, b) => a.period.compareTo(b.period));
    return AppCard(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text('Hôm nay - ${weekdayNames[wd - 1]}',
                  style: context.text.titleSmall),
            ),
            const SizedBox(height: Space.sm),
            if (todays.isEmpty)
              Text('Hôm nay không có tiết học',
                  style: context.text.bodyMedium
                      ?.copyWith(color: AppColors.muted)),
            for (final l in todays)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Text(
                  'Tiết ${l.period}: ${l.subject} - ${l.room} - ${l.teacherName}',
                  style: context.text.bodyMedium
                      ?.copyWith(color: AppColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.day, this.date, {required this.highlight});
  final String day;
  final String? date;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? Colors.white : AppColors.brandStrong;
    return Semantics(
      label: highlight ? '$day ${date ?? ''}, hôm nay' : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
        decoration: BoxDecoration(
            color: highlight ? AppColors.brandStrong : null,
            borderRadius: BorderRadius.circular(Radii.control)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(day,
              style: context.text.labelMedium?.copyWith(color: fg)),
          if (date != null)
            Text(date!,
                maxLines: 1,
                style: context.text.bodySmall
                    ?.copyWith(color: fg, height: 1.2)),
        ]),
      ),
    );
  }
}
