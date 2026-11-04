import 'package:flutter/material.dart';

import '../models/school.dart';
import '../theme/app_theme.dart';

/// "Học sinh" dropdown shown to parents with more than one child.
class StudentPicker extends StatelessWidget {
  const StudentPicker(
      {super.key,
      required this.students,
      required this.selectedId,
      required this.onChanged});

  final List<Student> students;
  final int selectedId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: DropdownButtonFormField<int>(
        key: const Key('studentPicker'),
        initialValue: selectedId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Học sinh'),
        items: [
          for (final s in students)
            DropdownMenuItem(
                value: s.id,
                child: Text('${s.name} - ${s.className}',
                    overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
