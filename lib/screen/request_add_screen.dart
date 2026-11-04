import 'package:flutter/material.dart';

import '../models/school.dart';
import '../models/user.dart';
import '../services/school_service.dart';
import '../theme/app_theme.dart';
import 'widgets.dart';

const requestTypes = ['Xin nghỉ học', 'Xin phép đi trễ', 'Xin đổi chỗ ngồi'];

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class RequestAddScreen extends StatefulWidget {
  const RequestAddScreen({super.key, required this.user, this.service});

  final User user;
  final SchoolService? service;

  @override
  State<RequestAddScreen> createState() => _RequestAddScreenState();
}

class _RequestAddScreenState extends State<RequestAddScreen> {
  late final SchoolService _svc = widget.service ?? SchoolService();
  late final Future<List<Student>> _students = _svc.children();
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late final _fromText = TextEditingController(text: fmtDate(_iso(_from)));
  late final _toText = TextEditingController(text: fmtDate(_iso(_to)));
  int? _studentId;
  String _type = requestTypes.first;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  bool _sending = false;
  String? _error;

  bool get _hasRange => _type == 'Xin nghỉ học';

  @override
  void dispose() {
    _reason.dispose();
    _fromText.dispose();
    _toText.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isFrom) async {
    final initial = isFrom ? _from : _to;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isFrom ? 'Chọn ngày bắt đầu' : 'Chọn ngày kết thúc',
    );
    if (d == null) return;
    setState(() {
      if (isFrom) {
        _from = d;
        if (_to.isBefore(d)) _to = d;
      } else {
        _to = d;
      }
      _fromText.text = fmtDate(_iso(_from));
      _toText.text = fmtDate(_iso(_to));
    });
  }

  Future<void> _submit() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    if (_studentId == null) {
      setState(() => _error = 'Vui lòng chọn học sinh');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _svc.createRequest(
        studentId: _studentId!,
        type: _type,
        fromDate: _iso(_from),
        toDate: _hasRange ? _iso(_to) : null,
        reason: _reason.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã gửi đơn')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = messageOf(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo đơn mới')),
      body: FutureView<List<Student>>(
        future: _students,
        onRetry: () => setState(() {}),
        builder: (context, students) {
          _studentId ??= students.length == 1 ? students.first.id : null;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.gutter, Space.gutter, Space.xxl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    key: const Key('studentField'),
                    initialValue: _studentId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Học sinh',
                      helperText: 'Học sinh cần làm đơn',
                    ),
                    items: [
                      for (final s in students)
                        DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.name} - ${s.className}',
                                overflow: TextOverflow.ellipsis)),
                    ],
                    validator: (v) => v == null ? 'Vui lòng chọn học sinh' : null,
                    onChanged: (v) => setState(() => _studentId = v),
                  ),
                  const SizedBox(height: Space.md),
                  DropdownButtonFormField<String>(
                    key: const Key('typeField'),
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Loại đơn',
                      helperText: 'Nghỉ học, đi trễ hoặc đổi chỗ ngồi',
                    ),
                    items: [
                      for (final t in requestTypes)
                        DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? _type),
                  ),
                  const SizedBox(height: Space.md),
                  _dates(context),
                  const SizedBox(height: Space.md),
                  TextFormField(
                    key: const Key('reasonField'),
                    controller: _reason,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: 500,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Lý do',
                      helperText: 'Nêu ngắn gọn lý do để giáo viên xem xét',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập lý do'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Space.sm),
                    InlineError(_error!, textKey: const Key('addError')),
                  ],
                  const SizedBox(height: Space.md),
                  PrimaryButton('Gửi đơn', loading: _sending, onPressed: _submit),
                  const SizedBox(height: Space.md),
                  PrimaryButton('Hủy',
                      outlined: true,
                      onPressed: _sending ? null : () => Navigator.pop(context)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dates(BuildContext context) {
    final from = _dateField(_hasRange ? 'Từ ngày' : 'Ngày', _fromText, true);
    if (!_hasRange) return from;
    final to = _dateField('Đến ngày', _toText, false);
    // Side by side only when two fields fit comfortably at the current text size.
    final roomy = MediaQuery.textScalerOf(context).scale(16) <= 18;
    return roomy
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: from),
            const SizedBox(width: Space.md),
            Expanded(child: to),
          ])
        : Column(children: [from, const SizedBox(height: Space.md), to]);
  }

  Widget _dateField(
      String label, TextEditingController controller, bool isFrom) {
    return TextFormField(
      key: Key(isFrom ? 'fromField' : 'toField'),
      controller: controller,
      readOnly: true,
      onTap: () => _pick(isFrom),
      decoration: InputDecoration(
        labelText: label,
        helperText: 'dd/mm/yyyy',
        suffixIcon: IconButton(
          tooltip: 'Chọn ngày',
          icon: const Icon(Icons.calendar_today_outlined, size: 20),
          onPressed: () => _pick(isFrom),
        ),
      ),
    );
  }
}
