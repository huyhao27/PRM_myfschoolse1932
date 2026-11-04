import 'package:flutter/material.dart';

import '../models/school.dart';
import '../theme/app_theme.dart';
import 'schedule_screen.dart' show weekdayNames;
import 'widgets.dart';

class ScheduleDetailScreen extends StatelessWidget {
  const ScheduleDetailScreen(
      {super.key, required this.lesson, required this.date});

  final Lesson lesson;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final when =
        '${weekdayNames[lesson.dayOfWeek - 1]}, ${two(date.day)}/${two(date.month)}/${date.year}'
        ' - Tiết ${lesson.period} (${lesson.startTime} - ${lesson.endTime})';
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết tiết học')),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Space.gutter, Space.gutter, Space.gutter, Space.xxl),
          children: [
            Container(
              padding: const EdgeInsets.all(Space.lg),
              decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(Radii.card)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(lesson.subject,
                        style: context.text.headlineSmall
                            ?.copyWith(color: AppColors.brandStrong)),
                  ),
                  const SizedBox(height: Space.xs + 2),
                  Text(when,
                      key: const Key('lessonWhen'),
                      style: context.text.bodyMedium
                          ?.copyWith(color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: Space.lg, vertical: Space.xs),
              child: Column(children: [
                InfoRow('Lớp', lesson.className),
                InfoRow('Phòng học', lesson.room),
                InfoRow('Giáo viên', lesson.teacherName),
                InfoRow('Hình thức', lesson.mode),
                InfoRow('Nội dung', lesson.content),
                InfoRow('Chuẩn bị', lesson.prep),
              ]),
            ),
            if (lesson.note.isNotEmpty)
              SectionCard('Ghi chú',
                  child: Text(lesson.note, style: context.text.bodyMedium)),
          ],
        ),
      ),
    );
  }
}
