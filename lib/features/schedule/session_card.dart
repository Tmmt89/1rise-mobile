import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:onerise_mobile/features/schedule/session_models.dart';

/// Card for a single session on the schedule.
///
/// Shows image (or level-based placeholder), title, teacher, time in
/// Moscow-local, and one primary action: Book / Cancel / Join,
/// depending on [state] + current booking.
///
/// Pure presentation widget — all mutations go through [onBook],
/// [onCancel], [onJoin] callbacks owned by the screen.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.onBook,
    required this.onCancel,
    required this.onJoin,
  });

  final SessionSummary session;
  final VoidCallback onBook;
  final VoidCallback onCancel;
  final VoidCallback onJoin;

  static final _timeFmt = DateFormat('HH:mm', 'ru_RU');
  static final _dateFmt = DateFormat('d MMM', 'ru_RU');

  @override
  Widget build(BuildContext context) {
    final moscow = session.startAtUtc.toUtc().add(const Duration(hours: 3));
    final timeText = _timeFmt.format(moscow);
    final dateText = _dateFmt.format(moscow);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumbnail(session: session),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.teacher,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _IconLabel(
                        icon: Icons.access_time,
                        label: '$dateText · $timeText',
                      ),
                      const SizedBox(width: 12),
                      _LevelBadge(level: session.level),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _actionButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context) {
    if (session.isLive && session.hasActiveBooking) {
      return FilledButton.icon(
        onPressed: _canJoin ? onJoin : null,
        icon: const Icon(Icons.videocam, size: 18),
        label: const Text('Подключиться'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.green.shade600,
        ),
      );
    }
    if (session.hasActiveBooking) {
      return OutlinedButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.close, size: 18),
        label: const Text('Отменить бронь'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade700,
        ),
      );
    }
    return FilledButton(
      onPressed: _canBook ? onBook : null,
      child: const Text('Записаться'),
    );
  }

  bool get _canBook => session.stateForUser == 'upcoming';

  bool get _canJoin =>
      session.hasBbb || (session.zoomLink?.isNotEmpty ?? false);
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.session});

  final SessionSummary session;

  @override
  Widget build(BuildContext context) {
    final colorByLevel = switch (session.level) {
      'Middle' => const Color(0xFFE2F5FF),
      'Advanced' => const Color(0xFFFCE9E9),
      _ => const Color(0xFFE9FCEA),
    };
    final placeholder = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: colorByLevel,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.school, color: Colors.black38),
    );
    if ((session.imageUrl ?? '').isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        session.imageUrl!,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  const _IconLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final label = switch (level) {
      'Middle' => 'Средний',
      'Advanced' => 'Продвинутый',
      _ => 'Начальный',
    };
    final color = switch (level) {
      'Middle' => const Color(0xFFE2F5FF),
      'Advanced' => const Color(0xFFFCE9E9),
      _ => const Color(0xFFE9FCEA),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
