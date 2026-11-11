import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:zyncro/design_system/context_extensions.dart';

// ── Audio player widget ───────────────────────────────────────────────────────

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  final int durationSeconds;
  final bool isMe;

  const AudioPlayerWidget({
    super.key,
    required this.url,
    required this.durationSeconds,
    required this.isMe,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final AudioPlayer _player;
  double _speed = 1.0;
  double _lastTapDx = 0;
  bool _urlLoaded = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
  }

  Future<void> _ensureUrlLoaded() async {
    if (_isDisposed || _urlLoaded || widget.url.isEmpty) return;
    _urlLoaded = true;
    try {
      await _player.setUrl(widget.url);
    } catch (_) {
      if (!_isDisposed) _urlLoaded = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_player.dispose());
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _seekTo(double dx, double width) {
    final total = _player.duration;
    if (total == null || total.inMilliseconds == 0) return;
    final ratio = (dx / width).clamp(0.0, 1.0);
    unawaited(
      _player.seek(
        Duration(milliseconds: (total.inMilliseconds * ratio).round()),
      ),
    );
  }

  void _toggleSpeed() {
    final next = _speed == 1.0 ? 2.0 : 1.0;
    setState(() => _speed = next);
    unawaited(_player.setSpeed(next));
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Duration(seconds: widget.durationSeconds);

    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, stateSnap) {
        final state = stateSnap.data;
        final isPlaying = state?.playing ?? false;
        final isLoading =
            state?.processingState == ProcessingState.loading ||
            state?.processingState == ProcessingState.buffering;

        return StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, posSnap) {
            final position = posSnap.data ?? Duration.zero;
            final total = _player.duration ?? fallback;
            final progress = total.inMilliseconds > 0
                ? (position.inMilliseconds / total.inMilliseconds).clamp(
                    0.0,
                    1.0,
                  )
                : 0.0;

            final fg = widget.isMe
                ? Colors.white
                : Theme.of(context).colorScheme.primary;
            final fgFaded = widget.isMe
                ? Colors.white.withValues(alpha: 0.35)
                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.25);

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: isLoading
                      ? null
                      : () async {
                          if (isPlaying) {
                            await _player.pause();
                          } else {
                            await _ensureUrlLoaded();
                            if (!mounted) return;
                            if (_player.processingState ==
                                ProcessingState.completed) {
                              await _player.seek(Duration.zero);
                            }
                            if (!mounted) return;
                            await _player.play();
                          }
                        },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.isMe
                          ? Colors.white.withValues(alpha: 0.25)
                          : Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(9),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: fg,
                            ),
                          )
                        : Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 20,
                            color: fg,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            // onTap consomme l'événement → empêche l'affichage
                            // du timestamp par le parent
                            onTap: () =>
                                _seekTo(_lastTapDx, constraints.maxWidth),
                            onTapDown: (d) {
                              _lastTapDx = d.localPosition.dx;
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: fgFaded,
                                  valueColor: AlwaysStoppedAnimation(fg),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${_fmt(position)} / ${_fmt(total)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: widget.isMe
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : context.colors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          // ── -5s ──
                          GestureDetector(
                            onTap: () {
                              final t = position - const Duration(seconds: 5);
                              unawaited(
                                _player.seek(
                                  t < Duration.zero ? Duration.zero : t,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(Icons.replay_5, size: 24, color: fg),
                            ),
                          ),
                          // ── +5s ──
                          GestureDetector(
                            onTap: () {
                              final t = position + const Duration(seconds: 5);
                              unawaited(_player.seek(t > total ? total : t));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(Icons.forward_5, size: 24, color: fg),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // ── vitesse ──
                          GestureDetector(
                            onTap: _toggleSpeed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: widget.isMe
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _speed == 1.0 ? '1×' : '2×',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: fg,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
