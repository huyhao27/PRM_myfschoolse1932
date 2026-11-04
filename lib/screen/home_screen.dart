import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/school_service.dart';
import '../theme/app_theme.dart';
import 'club_list_screen.dart';
import 'fpt_logo.dart';
import 'grade_screen.dart';
import 'login_screen.dart';
import 'request_list_screen.dart';
import 'schedule_screen.dart';
import 'widgets.dart';

class _Tile {
  const _Tile(this.id, this.label, this.icon, this.roles);
  final String id;
  final String label;
  final IconData icon;
  final Set<String> roles;
}

const _allRoles = {'GV', 'Manager', 'PH', 'HS'};

// Tiles per the whiteboard. Grades are for families and students only.
const _tiles = [
  _Tile('Schedule', 'Thời khóa biểu', Icons.calendar_month_outlined,
      _allRoles),
  _Tile('Grade', 'Bảng điểm', Icons.grade_outlined, {'PH', 'HS'}),
  _Tile('Request', 'Đơn từ', Icons.description_outlined, _allRoles),
  _Tile('Club', 'Câu lạc bộ', Icons.groups_outlined, _allRoles),
];

/// Tile labels visible for a role. Unknown roles see nothing.
List<String> tilesForRole(String role) =>
    _tiles.where((t) => t.roles.contains(role)).map((t) => t.label).toList();

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user, this.service});

  final User user;

  /// Shared by the feature screens; injectable for tests.
  final SchoolService? service;

  void _logout(BuildContext context) {
    Session.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _screenFor(String id) {
    final svc = service ?? SchoolService();
    return switch (id) {
      'Schedule' => ScheduleScreen(user: user, service: svc),
      'Grade' => GradeScreen(user: user, service: svc),
      'Request' => RequestListScreen(user: user, service: svc),
      _ => ClubListScreen(user: user, service: svc),
    };
  }

  @override
  Widget build(BuildContext context) {
    final visible = _tiles.where((t) => t.roles.contains(user.role)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          // White chip so the colored logo stays readable on the orange bar.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Radii.control)),
            child: const FptLogo(height: 22),
          ),
          const SizedBox(width: Space.md),
          const Flexible(
              child: Text('MyFSchool', overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: PageBody(
          child: Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _profile(context),
                const SizedBox(height: Space.lg),
                Expanded(
                  child: GridView(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: Space.md,
                      crossAxisSpacing: Space.md,
                      // Icon, up to three label lines and padding; grows with text size.
                      mainAxisExtent: 72 +
                          MediaQuery.textScalerOf(context).scale(20) * 3,
                    ),
                    children: [
                      for (final t in visible) _tile(context, t),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profile(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.brandSoft,
            child: ExcludeSemantics(
              child: Text(_initials(user.name),
                  style: context.text.titleSmall
                      ?.copyWith(color: AppColors.brandStrong)),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Xin chào, ${user.name}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall),
                const SizedBox(height: Space.xs),
                _RoleChip(roleName(user.role)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tile(BuildContext context, _Tile t) {
    final radius = BorderRadius.circular(Radii.card);
    return Semantics(
      button: true,
      label: t.label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: const BorderSide(color: AppColors.line)),
        child: InkWell(
          key: Key('tile_${t.id}'),
          borderRadius: radius,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _screenFor(t.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t.icon, size: 40, color: AppColors.brand),
                const SizedBox(height: Space.sm),
                Text(t.label,
                    textAlign: TextAlign.center,
                    style: context.text.titleSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Space.sm + 2, vertical: 2),
        decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(Radii.pill)),
        child: Text(label,
            style: context.text.labelMedium
                ?.copyWith(color: AppColors.brandStrong)),
      );
}
