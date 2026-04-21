import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// One participant tile: video feed + name + muted indicators.
///
/// The tile is a StatefulWidget because we subscribe to the
/// participant's events locally — every `TrackPublished` or
/// `TrackMuted` on this participant triggers a rebuild of just
/// this tile, not the whole grid. Cheaper than bubbling through
/// a shared provider.
class ParticipantTile extends StatefulWidget {
  const ParticipantTile({
    super.key,
    required this.participant,
    required this.isLocal,
  });

  final Participant participant;
  final bool isLocal;

  @override
  State<ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<ParticipantTile> {
  late final EventsListener<ParticipantEvent> _listener;
  VideoTrack? _videoTrack;

  @override
  void initState() {
    super.initState();
    _refreshVideo();
    _listener = widget.participant.createListener()
      ..on<TrackSubscribedEvent>((_) => _refreshVideo())
      ..on<TrackUnsubscribedEvent>((_) => _refreshVideo())
      ..on<LocalTrackPublishedEvent>((_) => _refreshVideo())
      ..on<LocalTrackUnpublishedEvent>((_) => _refreshVideo())
      ..on<TrackMutedEvent>((_) => _rebuild())
      ..on<TrackUnmutedEvent>((_) => _rebuild());
  }

  @override
  void didUpdateWidget(covariant ParticipantTile old) {
    super.didUpdateWidget(old);
    if (old.participant != widget.participant) {
      _listener.dispose();
      _refreshVideo();
    }
  }

  void _refreshVideo() {
    if (!mounted) return;
    final track = _pickVideoTrack(widget.participant);
    setState(() => _videoTrack = track);
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() {});
  }

  VideoTrack? _pickVideoTrack(Participant p) {
    // Prefer camera track over screen share for the default grid
    // render. Screen share deserves a bigger slot (T3 future work).
    for (final pub in p.videoTrackPublications) {
      final t = pub.track;
      if (t is VideoTrack && pub.source == TrackSource.camera) {
        return t;
      }
    }
    // Fallback: any video track, including screen.
    for (final pub in p.videoTrackPublications) {
      final t = pub.track;
      if (t is VideoTrack) return t;
    }
    return null;
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.participant.name.isNotEmpty
        ? widget.participant.name
        : widget.participant.identity;
    final micOn = widget.participant.isMicrophoneEnabled();
    final camOn = widget.participant.isCameraEnabled();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoTrack != null && camOn)
            VideoTrackRenderer(
              _videoTrack!,
              fit: VideoViewFit.cover,
              mirrorMode: widget.isLocal
                  ? VideoViewMirrorMode.mirror
                  : VideoViewMirrorMode.off,
            )
          else
            Center(
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.grey.shade700,
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          // Name + mute badge overlay at bottom.
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.isLocal ? '$name (вы)' : name,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const Spacer(),
                if (!micOn) const _StatusPill(icon: Icons.mic_off),
                if (!camOn) ...[
                  const SizedBox(width: 4),
                  const _StatusPill(icon: Icons.videocam_off),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.red.shade700.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: Colors.white, size: 12),
    );
  }
}
