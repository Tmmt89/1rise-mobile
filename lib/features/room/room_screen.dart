import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:onerise_mobile/features/room/participant_tile.dart';
import 'package:onerise_mobile/features/room/room_models.dart';
import 'package:onerise_mobile/features/room/room_repository.dart';

/// Native LiveKit room screen. The Flutter analogue of
/// `client/src/pages/LiveKitRoom.tsx` in the web app.
///
/// State machine:
///   loading     — initial screen, asking for perms + calling /join.
///   waiting     — /join returned 202; poll every 5 s.
///   connecting  — /join returned 200; calling Room.connect().
///   connected   — room is live, grid + toolbar shown.
///   error       — terminal; user taps Back.
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

enum _RoomState { loading, waiting, connecting, connected, error }

class _RoomScreenState extends ConsumerState<RoomScreen> {
  static const _waitingPollInterval = Duration(seconds: 5);

  _RoomState _state = _RoomState.loading;
  String _statusMessage = 'Подключаемся…';
  String _errorMessage = '';
  String _sessionTitle = '';
  String _role = 'attendee';

  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  Timer? _pollTimer;

  // Local device state (the participant has these as well, but UI
  // needs synchronous access for toolbar button tint).
  bool _micOn = true;
  bool _camOn = true;

  final List<Participant> _participants = [];

  @override
  void initState() {
    super.initState();
    // Perms first, then join. If perms are declined we still let the
    // user join as a viewer (LiveKit supports subscribe-only).
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _roomListener?.dispose();
    // Fire-and-forget; disconnect closes the WebSocket and cleans up
    // native resources. Awaiting would block dispose which Flutter
    // forbids.
    unawaited(_room?.disconnect());
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final granted = await _requestMedia();
    if (!mounted) return;
    if (!granted) {
      // User declined — we still attempt to join as a passive viewer.
      // They'll see others but can't publish.
      debugPrint('mic/cam permissions declined — joining as viewer');
    }
    await _attemptJoin();
  }

  Future<bool> _requestMedia() async {
    final statuses = await [
      Permission.microphone,
      Permission.camera,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Future<void> _attemptJoin() async {
    if (!mounted) return;
    setState(() {
      _state = _RoomState.loading;
      _statusMessage = 'Подключаемся…';
    });
    try {
      final repo = await ref.read(roomRepositoryProvider.future);
      final result = await repo.join(widget.sessionId);
      if (!mounted) return;

      switch (result) {
        case RoomJoinWaiting(:final message):
          setState(() {
            _state = _RoomState.waiting;
            _statusMessage = message;
          });
          _pollTimer?.cancel();
          _pollTimer = Timer(_waitingPollInterval, _attemptJoin);
          return;
        case RoomJoinReady(:final response):
          setState(() {
            _sessionTitle = response.sessionTitle;
            _role = response.role;
            _state = _RoomState.connecting;
            _statusMessage = 'Соединяемся с комнатой…';
          });
          await _connectRoom(response);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _RoomState.error;
        _errorMessage = _clean(e);
      });
    }
  }

  Future<void> _connectRoom(RoomJoinResponse r) async {
    final room = Room();
    _roomListener = room.createListener()
      ..on<RoomDisconnectedEvent>((_) {
        if (!mounted) return;
        setState(() {
          _state = _RoomState.error;
          _errorMessage = _errorMessage.isEmpty
              ? 'Соединение с комнатой потеряно'
              : _errorMessage;
        });
      })
      ..on<ParticipantConnectedEvent>((_) => _refreshParticipants())
      ..on<ParticipantDisconnectedEvent>((_) => _refreshParticipants())
      ..on<TrackSubscribedEvent>((_) => _refreshParticipants())
      ..on<TrackUnsubscribedEvent>((_) => _refreshParticipants())
      ..on<LocalTrackPublishedEvent>((_) => _refreshParticipants())
      // Local track muted by server (moderator force-mute) → sync toolbar.
      ..on<TrackMutedEvent>((e) => _maybeSyncLocalToggles(e.participant, room))
      ..on<TrackUnmutedEvent>((e) => _maybeSyncLocalToggles(e.participant, room));

    try {
      await room.connect(r.wsUrl, r.token);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _RoomState.error;
        _errorMessage = _clean(e);
      });
      unawaited(room.disconnect());
      return;
    }

    // Publish mic + camera. Failures are non-fatal — the user can
    // still subscribe to others. Explicit try/catch around each so a
    // single device failure (e.g. no camera on an iPad) doesn't kill
    // the whole room.
    try {
      await room.localParticipant?.setMicrophoneEnabled(true);
    } catch (e) {
      debugPrint('mic publish failed: $e');
    }
    try {
      await room.localParticipant?.setCameraEnabled(true);
    } catch (e) {
      debugPrint('camera publish failed: $e');
    }

    if (!mounted) {
      unawaited(room.disconnect());
      return;
    }

    setState(() {
      _room = room;
      _state = _RoomState.connected;
      _micOn = room.localParticipant?.isMicrophoneEnabled() ?? true;
      _camOn = room.localParticipant?.isCameraEnabled() ?? true;
    });
    _refreshParticipants();
  }

  void _refreshParticipants() {
    final room = _room;
    if (room == null || !mounted) return;
    final local = room.localParticipant;
    setState(() {
      _participants
        ..clear()
        ..addAll([
          if (local != null) local,
          ...room.remoteParticipants.values,
        ]);
    });
  }

  /// Invoked on TrackMuted/Unmuted — if the affected participant is
  /// the local one (server force-muted us), pull fresh values off
  /// the participant so the toolbar buttons flip red in lockstep.
  void _maybeSyncLocalToggles(Participant participant, Room room) {
    final local = room.localParticipant;
    if (local == null || participant != local) return;
    if (!mounted) return;
    setState(() {
      _micOn = local.isMicrophoneEnabled();
      _camOn = local.isCameraEnabled();
    });
  }

  Future<void> _toggleMic() async {
    final p = _room?.localParticipant;
    if (p == null) return;
    final next = !_micOn;
    try {
      await p.setMicrophoneEnabled(next);
      setState(() => _micOn = next);
    } catch (e) {
      debugPrint('mic toggle failed: $e');
    }
  }

  Future<void> _toggleCam() async {
    final p = _room?.localParticipant;
    if (p == null) return;
    final next = !_camOn;
    try {
      await p.setCameraEnabled(next);
      setState(() => _camOn = next);
    } catch (e) {
      debugPrint('cam toggle failed: $e');
    }
  }

  void _leave() {
    unawaited(_room?.disconnect());
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  String _clean(Exception e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring('Exception: '.length) : s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        title: Text(_sessionTitle.isEmpty ? 'Урок' : _sessionTitle),
        actions: [
          if (_state == _RoomState.connected)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${_role == "moderator" ? "Модератор" : "Участник"} · '
                  '${_participants.length}',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (_state) {
          _RoomState.loading || _RoomState.connecting =>
            _StatusBody(message: _statusMessage, showSpinner: true),
          _RoomState.waiting => _StatusBody(
              message: _statusMessage,
              showSpinner: true,
              icon: Icons.hourglass_top,
            ),
          _RoomState.error => _ErrorBody(
              message: _errorMessage,
              onBack: _leave,
            ),
          _RoomState.connected => _ConnectedBody(
              participants: _participants,
              micOn: _micOn,
              camOn: _camOn,
              onMicToggle: _toggleMic,
              onCamToggle: _toggleCam,
              onLeave: _leave,
            ),
        },
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({
    required this.message,
    required this.showSpinner,
    this.icon,
  });

  final String message;
  final bool showSpinner;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showSpinner)
            const CircularProgressIndicator(color: Colors.white)
          else if (icon != null)
            Icon(icon, color: Colors.white70, size: 48),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onBack, child: const Text('Назад')),
        ],
      ),
    );
  }
}

class _ConnectedBody extends StatelessWidget {
  const _ConnectedBody({
    required this.participants,
    required this.micOn,
    required this.camOn,
    required this.onMicToggle,
    required this.onCamToggle,
    required this.onLeave,
  });

  final List<Participant> participants;
  final bool micOn;
  final bool camOn;
  final VoidCallback onMicToggle;
  final VoidCallback onCamToggle;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _ParticipantGrid(participants: participants),
          ),
        ),
        _Toolbar(
          micOn: micOn,
          camOn: camOn,
          onMicToggle: onMicToggle,
          onCamToggle: onCamToggle,
          onLeave: onLeave,
        ),
      ],
    );
  }
}

class _ParticipantGrid extends StatelessWidget {
  const _ParticipantGrid({required this.participants});

  final List<Participant> participants;

  @override
  Widget build(BuildContext context) {
    // Columns: 1 until 3 participants, 2 above. Phone-friendly.
    final cols = participants.length <= 1
        ? 1
        : (participants.length <= 4 ? 2 : 3);
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3 / 4,
      ),
      itemCount: participants.length,
      itemBuilder: (_, idx) {
        final p = participants[idx];
        return ParticipantTile(
          participant: p,
          isLocal: p is LocalParticipant,
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.micOn,
    required this.camOn,
    required this.onMicToggle,
    required this.onCamToggle,
    required this.onLeave,
  });

  final bool micOn;
  final bool camOn;
  final VoidCallback onMicToggle;
  final VoidCallback onCamToggle;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarButton(
            icon: micOn ? Icons.mic : Icons.mic_off,
            label: micOn ? 'Микрофон' : 'Микр. выкл.',
            active: micOn,
            onTap: onMicToggle,
          ),
          _ToolbarButton(
            icon: camOn ? Icons.videocam : Icons.videocam_off,
            label: camOn ? 'Камера' : 'Кам. выкл.',
            active: camOn,
            onTap: onCamToggle,
          ),
          _ToolbarButton(
            icon: Icons.call_end,
            label: 'Выйти',
            active: false,
            destructive: true,
            onTap: onLeave,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = destructive
        ? Colors.red.shade700
        : (active ? Colors.white12 : Colors.red.shade700.withValues(alpha: 0.85));
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
