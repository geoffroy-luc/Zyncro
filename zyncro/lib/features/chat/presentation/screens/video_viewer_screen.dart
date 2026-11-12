import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:zyncro/core/utils/duration_format.dart';
import 'package:zyncro/features/chat/presentation/widgets/media_downloader.dart';
import 'package:zyncro/features/chat/presentation/widgets/media_viewer_helpers.dart';

// ── Vidéo fullscreen ──────────────────────────────────────────────────────────

class VideoViewerScreen extends StatefulWidget {
  final String url;
  final String? senderName;
  final DateTime? sentAt;

  const VideoViewerScreen({
    super.key,
    required this.url,
    this.senderName,
    this.sentAt,
  });

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _failed = false;
  bool _downloading = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    unawaited(
      _controller
          .initialize()
          .then((_) {
            if (mounted) {
              setState(() => _initialized = true);
              unawaited(_controller.play());
            }
          })
          .catchError((Object _) {
            // BUG M14 corrigé : erreur affichée au lieu d'un spinner infini.
            if (mounted) setState(() => _failed = true);
          }),
    );
    unawaited(_controller.setLooping(true));
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    unawaited(_controller.dispose());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    await MediaDownloader.downloadVideo(context, widget.url);
    if (mounted) setState(() => _downloading = false);
  }

  String _fmtDuration(Duration d) => formatDuration(d);

  @override
  Widget build(BuildContext context) {
    final position = _initialized ? _controller.value.position : Duration.zero;
    final duration = _initialized ? _controller.value.duration : Duration.zero;
    final isPlaying = _initialized && _controller.value.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        onLongPress: _download,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Vidéo ───────────────────────────────────────────────────
            Center(
              child: _initialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : _failed
                  ? const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white70,
                      size: 48,
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),

            // BUG M14 corrigé : bouton retour disponible pendant le
            // chargement et en cas d'erreur.
            if (!_initialized)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),

            // ── Overlay contrôles ───────────────────────────────────────
            if (_showControls && _initialized) ...[
              // Bouton retour + infos + download (haut)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.senderName != null)
                                Text(
                                  widget.senderName!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (widget.sentAt != null)
                                Text(
                                  viewerFormatDateTime(widget.sentAt!),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_downloading)
                          const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(
                              Icons.download_outlined,
                              color: Colors.white,
                            ),
                            onPressed: _download,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Play/pause + barre de progression (bas)
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
                        // Play / Pause
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            unawaited(
                              isPlaying
                                  ? _controller.pause()
                                  : _controller.play(),
                            );
                          },
                        ),

                        // Temps écoulé
                        Text(
                          _fmtDuration(position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),

                        // Slider seek
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
                            onChanged: (v) {
                              unawaited(
                                _controller.seekTo(
                                  Duration(milliseconds: v.toInt()),
                                ),
                              );
                            },
                          ),
                        ),

                        // Durée totale
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
          ],
        ),
      ),
    );
  }
}
