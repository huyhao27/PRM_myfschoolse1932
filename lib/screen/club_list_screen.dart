import 'package:flutter/material.dart';

import '../models/school.dart';
import '../models/user.dart';
import '../services/school_service.dart';
import '../theme/app_theme.dart';
import 'club_detail_screen.dart';
import 'widgets.dart';

/// Seed icons are text glyphs; map the known ones to Material icons so the
/// app shows one icon family. Unknown keys fall back to the text.
const clubIcons = <String, IconData>{
  '</>': Icons.code,
  '⚽': Icons.sports_soccer,
  '♪': Icons.music_note,
  '✎': Icons.brush,
  '●': Icons.sports_basketball,
};

IconData? clubIconData(String key) => clubIcons[key.trim()];

/// The club's icon (or its text) drawn at [size] in [color].
class ClubGlyph extends StatelessWidget {
  const ClubGlyph(this.text,
      {super.key, required this.size, this.color = AppColors.brandStrong});
  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = clubIconData(text);
    return ExcludeSemantics(
      child: icon != null
          ? Icon(icon, size: size, color: color)
          : Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: size * 0.7)),
    );
  }
}

/// Round avatar with the club icon, shared by list and detail.
class ClubAvatar extends StatelessWidget {
  const ClubAvatar(this.text, {super.key, this.radius = 22});
  final String text;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.brandSoft,
        child: ClubGlyph(text, size: radius * 1.0),
      );
}

StatusBadge? membershipBadge(String? status, {required bool canJoin}) {
  switch (status) {
    case 'approved':
      return const StatusBadge(StatusKind.approved, 'Đã tham gia');
    case 'pending':
      return const StatusBadge(StatusKind.pending, 'Chờ duyệt');
    default:
      return canJoin ? const StatusBadge(StatusKind.action, 'Tham gia') : null;
  }
}

class ClubListScreen extends StatefulWidget {
  const ClubListScreen({super.key, required this.user, this.service});

  final User user;
  final SchoolService? service;

  @override
  State<ClubListScreen> createState() => _ClubListScreenState();
}

class _ClubListScreenState extends State<ClubListScreen> {
  late final SchoolService _svc = widget.service ?? SchoolService();
  late Future<List<ClubItem>> _future = _svc.clubs();
  String _query = '';

  void _reload() => setState(() {
        _future = _svc.clubs();
      });

  Future<void> _refresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _open(ClubItem c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ClubDetailScreen(user: widget.user, clubId: c.id, service: _svc),
      ),
    );
    if (mounted) _reload(); // membership may have changed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Câu lạc bộ')),
      body: Column(
        children: [
          PageBody(
            child: Padding(
              padding: const EdgeInsets.all(Space.gutter),
              child: TextField(
                key: const Key('clubSearch'),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Tìm câu lạc bộ',
                  prefixIcon: const ExcludeSemantics(child: Icon(Icons.search)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.pill)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.pill),
                      borderSide: const BorderSide(color: AppColors.control)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.pill),
                      borderSide: const BorderSide(
                          color: AppColors.brandStrong, width: 2)),
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
          ),
          Expanded(
            child: FutureView<List<ClubItem>>(
              future: _future,
              onRetry: _reload,
              builder: (context, all) {
                final items = all
                    .where((c) => c.name.toLowerCase().contains(_query))
                    .toList();
                return RefreshList(
                  onRefresh: _refresh,
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, 0, Space.gutter, Space.xxl),
                  children: [
                    if (items.isEmpty)
                      const EmptyState(
                          icon: Icons.search_off,
                          message: 'Không tìm thấy câu lạc bộ nào'),
                    for (final c in items) _card(c),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(ClubItem c) {
    final badge =
        membershipBadge(c.myStatus, canJoin: widget.user.role == 'HS');
    return AppCard(
      onTap: () => _open(c),
      child: Row(children: [
        ClubAvatar(c.icon),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.name, style: context.text.titleSmall),
              const SizedBox(height: Space.xs),
              Text('${c.memberCount} thành viên', style: context.text.bodySmall),
            ],
          ),
        ),
        if (badge != null) ...[const SizedBox(width: Space.sm), badge],
      ]),
    );
  }
}
