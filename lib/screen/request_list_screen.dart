import 'package:flutter/material.dart';

import '../models/school.dart';
import '../models/user.dart';
import '../services/school_service.dart';
import '../theme/app_theme.dart';
import 'request_add_screen.dart';
import 'request_detail_screen.dart';
import 'widgets.dart';

String statusLabel(String s) => switch (s) {
      'pending' => 'Chờ duyệt',
      'approved' => 'Đã duyệt',
      'rejected' => 'Từ chối',
      _ => s,
    };

/// "Nghỉ 15/10 - 16/10/2026" or "Ngày 12/10/2026".
String requestDateText(RequestItem r) {
  if (r.fromDate.isEmpty) return '';
  if (r.type != 'Xin nghỉ học') return 'Ngày ${fmtDate(r.fromDate)}';
  if (r.toDate.isEmpty || r.toDate == r.fromDate) {
    return 'Nghỉ ${fmtDate(r.fromDate)}';
  }
  return 'Nghỉ ${fmtDay(r.fromDate)} - ${fmtDate(r.toDate)}';
}

class RequestListScreen extends StatefulWidget {
  const RequestListScreen({super.key, required this.user, this.service});

  final User user;
  final SchoolService? service;

  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  late final SchoolService _svc = widget.service ?? SchoolService();
  late Future<List<RequestItem>> _future = _svc.requests();
  String? _filter; // null = all

  bool get _canCreate => widget.user.role == 'PH' || widget.user.role == 'HS';

  void _reload() => setState(() {
        _future = _svc.requests();
      });

  Future<void> _refresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _open(Widget screen) async {
    final changed = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => screen));
    if (changed == true) _reload();
  }

  void _create() =>
      _open(RequestAddScreen(user: widget.user, service: _svc));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn từ')),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              key: const Key('addRequest'),
              tooltip: 'Tạo đơn mới',
              onPressed: _create,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          PageBody(child: _filters()),
          Expanded(
            child: FutureView<List<RequestItem>>(
              future: _future,
              onRetry: _reload,
              builder: (context, all) {
                final items = _filter == null
                    ? all
                    : all.where((r) => r.status == _filter).toList();
                return RefreshList(
                  onRefresh: _refresh,
                  // Room under the floating button so the last card stays reachable.
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, Space.xs, Space.gutter, 96),
                  children: [
                    if (items.isEmpty)
                      EmptyState(
                        icon: Icons.description_outlined,
                        message: 'Chưa có đơn nào',
                        actionLabel:
                            _canCreate && _filter == null ? 'Tạo đơn' : null,
                        onAction: _create,
                      ),
                    for (final r in items) _card(r),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    const options = [
      (null, 'Tất cả'),
      ('pending', 'Chờ duyệt'),
      ('approved', 'Đã duyệt'),
      ('rejected', 'Từ chối'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: Space.gutter, vertical: Space.sm),
      child: Row(children: [
        for (final (value, label) in options)
          Padding(
            padding: const EdgeInsets.only(right: Space.sm),
            child: SizedBox(
              height: Space.minTap,
              child: ChoiceChip(
                key: Key('filter_${value ?? 'all'}'),
                label: Text(label),
                selected: _filter == value,
                labelStyle: context.text.labelLarge?.copyWith(
                    color: _filter == value ? Colors.white : AppColors.muted),
                side: BorderSide(
                    color: _filter == value
                        ? AppColors.brandStrong
                        : AppColors.control),
                onSelected: (_) => setState(() => _filter = value),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _card(RequestItem r) {
    final muted = context.text.bodyMedium?.copyWith(color: AppColors.muted);
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: Space.xs),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExcludeSemantics(
                child: Icon(icon, size: 16, color: AppColors.muted)),
            const SizedBox(width: Space.sm - 2),
            Expanded(child: Text(text, style: muted)),
          ]),
        );
    return AppCard(
      onTap: () => _open(
          RequestDetailScreen(user: widget.user, request: r, service: _svc)),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(r.type, style: context.text.titleSmall),
              ),
              const SizedBox(width: Space.sm),
              StatusBadge.request(r.status),
            ]),
            const SizedBox(height: Space.xs),
            line(Icons.person_outline,
                '${r.student.name} - ${r.student.className}'),
            line(Icons.event_outlined, requestDateText(r)),
          ],
        ),
      ),
    );
  }
}
