import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import 'app_colors.dart';
import 'login_screen.dart';

class _Tile {
  const _Tile(this.label, this.icon, this.roles);
  final String label;
  final IconData icon;
  final Set<String> roles;
}

const _allRoles = {'GV', 'Manager', 'PH', 'HS'};

// Per the whiteboard: Schedule, Grade, Request (Don tu), Club.
// Currently every role sees all four; adjust the role sets to restrict.
const _tiles = [
  _Tile('Schedule', Icons.calendar_month, _allRoles),
  _Tile('Grade', Icons.grade, _allRoles),
  _Tile('Request', Icons.description, _allRoles),
  _Tile('Club', Icons.groups, _allRoles),
];

/// Tile labels visible for a role. Unknown roles see nothing.
List<String> tilesForRole(String role) =>
    _tiles.where((t) => t.roles.contains(role)).map((t) => t.label).toList();

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  void _logout(BuildContext context) {
    Session.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _tiles.where((t) => t.roles.contains(user.role)).toList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, ${user.name}',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text('Role: ${user.role}',
                style: const TextStyle(color: AppColors.textGray)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.extent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  for (final t in visible)
                    InkWell(
                      key: Key('tile_${t.label}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                            content: Text('${t.label}: coming soon'))),
                      child: Ink(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(t.icon, size: 40, color: AppColors.orange),
                            const SizedBox(height: 8),
                            Text(t.label,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
