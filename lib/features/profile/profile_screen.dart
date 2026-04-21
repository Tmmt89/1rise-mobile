import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onerise_mobile/features/auth/auth_controller.dart';
import 'package:onerise_mobile/features/profile/profile_repository.dart';

/// Profile tab. Minimum viable: show user identity, attendance stats,
/// and a big logout button. Admin surface (impersonation, cohort
/// counts, etc.) deliberately stays on the web app — see
/// `docs/PLAN.md` "Not in scope for v1".
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final statsAsync = ref.watch(profileStatsProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(profileStatsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (user != null) _HeaderCard(name: user.name, email: user.email),
            const SizedBox(height: 16),
            statsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Не удалось загрузить статистику: $e',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              data: (stats) => Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Посещено',
                      value: stats.attended.toString(),
                      color: Colors.green.shade100,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      label: 'Пропущено',
                      value: stats.missed.toString(),
                      color: Colors.orange.shade100,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: auth.loading
                  ? null
                  : () {
                      ref.read(authControllerProvider.notifier).logout();
                    },
              icon: const Icon(Icons.logout),
              label: const Text('Выйти'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                _initials(name),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }
}
