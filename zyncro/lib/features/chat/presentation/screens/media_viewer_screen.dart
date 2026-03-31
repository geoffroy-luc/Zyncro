import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

// ── Utilitaire de téléchargement partagé ─────────────────────────────────────

class MediaDownloader {
  static Future<void> downloadImage(BuildContext context, String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/zyncro_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.bodyBytes);
      file.setLastModifiedSync(DateTime.now());
      await Gal.putImage(file.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image enregistrée dans la galerie')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur téléchargement : $e')),
        );
      }
    }
  }

  static Future<void> downloadVideo(BuildContext context, String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/zyncro_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await file.writeAsBytes(response.bodyBytes);
      file.setLastModifiedSync(DateTime.now());
      await Gal.putVideo(file.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vidéo enregistrée dans la galerie')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur téléchargement : $e')),
        );
      }
    }
  }
}

// ── Image fullscreen ──────────────────────────────────────────────────────────

class ImageViewerScreen extends StatefulWidget {
  final String url;
  final String? senderName;
  final DateTime? sentAt;

  const ImageViewerScreen({super.key, required this.url, this.senderName, this.sentAt});

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _showControls = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    await MediaDownloader.downloadImage(context, widget.url);
    if (mounted) setState(() => _downloading = false);
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return "Aujourd'hui à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        onLongPress: _download,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Image zoomable ──────────────────────────────────────────
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(
                widget.url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      ),
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),

            // ── Overlay contrôles (masqué au tap) ──────────────────────
            if (_showControls)
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
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                                  _formatDateTime(widget.sentAt!),
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
                            icon: const Icon(Icons.download_outlined, color: Colors.white),
                            tooltip: 'Enregistrer',
                            onPressed: _download,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Vidéo fullscreen ──────────────────────────────────────────────────────────

class VideoViewerScreen extends StatefulWidget {
  final String url;
  final String? senderName;
  final DateTime? sentAt;

  const VideoViewerScreen({super.key, required this.url, this.senderName, this.sentAt});

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _downloading = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
    _controller.setLooping(true);
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    await MediaDownloader.downloadVideo(context, widget.url);
    if (mounted) setState(() => _downloading = false);
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return "Aujourd'hui à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
                  : const CircularProgressIndicator(color: Colors.white),
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
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                                  _formatDateTime(widget.sentAt!),
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
                            icon: const Icon(Icons.download_outlined, color: Colors.white),
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
                            isPlaying ? _controller.pause() : _controller.play();
                          },
                        ),

                        // Temps écoulé
                        Text(
                          _fmtDuration(position),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
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
                            min: 0,
                            max: duration.inMilliseconds > 0
                                ? duration.inMilliseconds.toDouble()
                                : 1,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white38,
                            thumbColor: Colors.white,
                            onChanged: (v) {
                              _controller.seekTo(
                                Duration(milliseconds: v.toInt()),
                              );
                            },
                          ),
                        ),

                        // Durée totale
                        Text(
                          _fmtDuration(duration),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
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
