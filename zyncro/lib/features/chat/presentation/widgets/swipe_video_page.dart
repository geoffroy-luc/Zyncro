import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// ── Page vidéo dans le swipe viewer ──────────────────────────────────────────

class SwipeVideoPage extends StatefulWidget {
  final String url;
  final bool isActive;
  final bool showControls;
  final VoidCallback onTap;

  const SwipeVideoPage({
    super.key,
    required this.url,
    required this.isActive,
    required this.showControls,
    required this.onTap,
  });

  @override
  State<SwipeVideoPage> createState() => _SwipeVideoPageState();
}

class _SwipeVideoPageState extends State<SwipeVideoPage> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    unawaited(
      _controller.initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          if (widget.isActive) unawaited(_controller.play());
        }
      }),
    );
    unawaited(_controller.setLooping(true));
    _controller.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(SwipeVideoPage old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      if (widget.isActive) {
        unawaited(_controller.play());
      } else {
        unawaited(_controller.pause());
        unawaited(_controller.seekTo(Duration.zero));
      }
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    unawaited(_controller.dispose());
    super.dispose();
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final position = _initialized ? _controller.value.position : Duration.zero;
    final duration = _initialized ? _controller.value.duration : Duration.zero;
    final isPlaying = _initialized && _controller.value.isPlaying;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: _initialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),

          // Contrôles vidéo (bas)
          if (widget.showControls && _initialized)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => isPlaying
                            ? _controller.pause()
                            : _controller.play(),
                      ),
                      Text(
                        _fmtDuration(position),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: duration.inMilliseconds > 0
                              ? position.inMilliseconds.toDouble().clamp(
                                  0,
                                  duration.inMilliseconds.toDouble(),
                                )
                              : 0,
                          max: duration.inMilliseconds > 0
                              ? duration.inMilliseconds.toDouble()
                              : 1,
                          activeColor: Colors.white,
                          inactiveColor: Colors.white38,
                          thumbColor: Colors.white,
                          onChanged: (v) => _controller.seekTo(
                            Duration(milliseconds: v.toInt()),
                          ),
                        ),
                      ),
                      Text(
                        _fmtDuration(duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
