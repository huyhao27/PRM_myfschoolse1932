import 'package:flutter/material.dart';

import '../models/school.dart';
import '../models/user.dart';
import '../services/school_service.dart';
import '../theme/app_theme.dart';
import 'request_list_screen.dart' show requestDateText;
import 'widgets.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen(
      {super.key, required this.user, required this.request, this.service});

  final User user;
  final RequestItem request;
  final SchoolService? service;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  late final SchoolService _svc = widget.service ?? SchoolService();
  final _comment = TextEditingController();
  bool _busy = false;
  String? _error;

  RequestItem get r => widget.request;
  bool get _canDecide =>
      r.isPending && (widget.user.role == 'GV' || widget.user.role == 'Manager');

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _decide(String decision) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _svc.decide(r.id, decision, _comment.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(decision == 'approved' ? 'Đã duyệt đơn' : 'Đã từ chối đơn')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = messageOf(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đơn')),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Space.gutter, Space.gutter, Space.gutter, Space.xxl),
          children: [
            Row(children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(r.type, style: context.text.titleLarge),
                ),
              ),
              const SizedBox(width: Space.sm),
              StatusBadge.request(r.status),
            ]),
            const SizedBox(height: Space.xs),
            Text('Gửi lúc ${fmtDateTime(r.createdAt)}',
                style: context.text.bodySmall),
            const SizedBox(height: Space.md),
            AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: Space.lg, vertical: Space.xs),
              child: Column(children: [
                InfoRow('Học sinh', r.student.name),
                InfoRow('Lớp', r.student.className),
                InfoRow('Người gửi',
                    '${roleName(r.creatorRole)} - ${r.creatorName}'),
                InfoRow('Thời gian', requestDateText(r)),
              ]),
            ),
            SectionCard('Lý do',
                child: Text(r.reason, style: context.text.bodyMedium)),
            if (!r.isPending) _handled(),
            if (_canDecide) ..._decision(),
          ],
        ),
      ),
    );
  }

  Widget _handled() {
    final who = r.handledByName == null ? '' : ' (${r.handledByName})';
    return SectionCard(
      'Ý kiến giáo viên$who',
      child: Text(
          (r.teacherComment ?? '').isEmpty
              ? 'Không có ý kiến'
              : r.teacherComment!,
          key: const Key('teacherComment'),
          style: context.text.bodyMedium),
    );
  }

  List<Widget> _decision() => [
        const SizedBox(height: Space.sm),
        TextField(
          key: const Key('commentField'),
          controller: _comment,
          minLines: 3,
          maxLines: 5,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Ý kiến giáo viên',
            hintText: 'Nhập ý kiến (tùy chọn)...',
            helperText: 'Phụ huynh và học sinh sẽ thấy ý kiến này',
            alignLabelWithHint: true,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.sm),
          InlineError(_error!, textKey: const Key('decisionError')),
        ],
        const SizedBox(height: Space.md),
        Row(children: [
          Expanded(
            child: PrimaryButton('Từ chối',
                color: AppColors.danger,
                onPressed: _busy ? null : () => _decide('rejected')),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: PrimaryButton('Duyệt',
                color: AppColors.success,
                onPressed: _busy ? null : () => _decide('approved')),
          ),
        ]),
      ];
}
