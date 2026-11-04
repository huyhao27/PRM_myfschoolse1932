import 'package:flutter/material.dart';

import '../models/school.dart';
import '../models/user.dart';
import '../services/school_service.dart';
import '../theme/app_theme.dart';
import 'club_list_screen.dart' show ClubAvatar, ClubGlyph;
import 'widgets.dart';

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
}

class ClubDetailScreen extends StatefulWidget {
  const ClubDetailScreen(
      {super.key, required this.user, required this.clubId, this.service});

  final User user;
  final int clubId;
  final SchoolService? service;

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen> {
  late final SchoolService _svc = widget.service ?? SchoolService();
  late Future<ClubDetail> _future = _svc.club(widget.clubId);
  bool _joining = false;
  String? _error;

  void _reload() => setState(() {
        _future = _svc.club(widget.clubId);
      });

  Future<void> _join() async {
    if (_joining) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await _svc.joinClub(widget.clubId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi yêu cầu tham gia')));
      _joining = false;
      _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _error = messageOf(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ClubDetail>(
      future: _future,
      builder: (context, snap) {
        final title = snap.data?.club.name ?? 'Câu lạc bộ';
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: FutureView<ClubDetail>(
            future: _future,
            onRetry: _reload,
            builder: (context, d) => _content(d),
          ),
        );
      },
    );
  }

  Widget _content(ClubDetail d) {
    final c = d.club;
    final more = c.memberCount - d.memberPreview.length;
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              Container(
                height: 150,
                decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(Radii.card)),
                margin: const EdgeInsets.fromLTRB(
                    Space.gutter, Space.gutter, Space.gutter, 0),
                alignment: Alignment.center,
                child: ClubGlyph(c.icon, size: 64),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(c.name, style: context.text.titleLarge),
                    ),
                    const SizedBox(height: Space.xs),
                    Text('${c.memberCount} thành viên - ${d.meeting}',
                        style: context.text.bodyMedium
                            ?.copyWith(color: AppColors.muted)),
                    const SizedBox(height: Space.lg),
                    SectionCard('Giới thiệu',
                        child: Text(d.description,
                            style: context.text.bodyMedium)),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Space.lg, vertical: Space.xs),
                      child: Column(children: [
                        InfoRow('Chủ nhiệm CLB', d.advisor),
                        InfoRow('Địa điểm', d.location),
                        InfoRow('Chủ tịch', d.president),
                      ]),
                    ),
                    const SizedBox(height: Space.xs),
                    Semantics(
                      header: true,
                      child: Text('Thành viên', style: context.text.titleSmall),
                    ),
                    const SizedBox(height: Space.sm),
                    Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                      for (final n in d.memberPreview)
                        Semantics(
                          label: n,
                          child: ExcludeSemantics(
                              child: ClubAvatar(_initials(n), radius: 20)),
                        ),
                      if (more > 0)
                        Semantics(
                          label: 'và $more thành viên khác',
                          child: ExcludeSemantics(
                              child: ClubAvatar('+$more', radius: 20)),
                        ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.sm, Space.gutter, Space.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  InlineError(_error!, textKey: const Key('joinError')),
                  const SizedBox(height: Space.sm),
                ],
                if (widget.user.role == 'HS') _joinButton(c),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _joinButton(ClubItem c) {
    final (label, enabled) = switch (c.myStatus) {
      'approved' => ('Đã tham gia', false),
      'pending' => ('Đang chờ duyệt', false),
      _ => ('Tham gia câu lạc bộ', true),
    };
    return PrimaryButton(label,
        loading: _joining, onPressed: enabled ? _join : null);
  }
}
