import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// ── Vignette vidéo (premier frame) ──────────────────────────────────────────

class VideoThumbnail extends StatefulWidget {
  final String url;
  const VideoThumbnail({super.key, required this.url});

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  late VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    unawaited(
      _controller.initialize().then((_) {
        if (mounted) {
          unawaited(_controller.seekTo(Duration.zero));
          setState(() => _ready = true);
        }
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 220,
        height: 130,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            else
              const ColoredBox(color: Color(0xFF1A1A1A)),
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                size: 48,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
