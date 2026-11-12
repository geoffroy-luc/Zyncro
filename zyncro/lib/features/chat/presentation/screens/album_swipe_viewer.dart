import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zyncro/features/chat/presentation/widgets/media_downloader.dart';
import 'package:zyncro/features/chat/presentation/widgets/media_viewer_helpers.dart';
import 'package:zyncro/features/chat/presentation/widgets/swipe_image_page.dart';
import 'package:zyncro/features/chat/presentation/widgets/swipe_video_page.dart';

// ── Album swipe viewer (pour les messages multi-médias) ───────────────────────

/// Viewer plein-écran swipeable pour une liste plate de médias.
///
/// Chaque item dans [medias] peut contenir :
///   - 'url'        (String, obligatoire)
///   - 'mimeType'   (String, obligatoire)
///   - 'senderName' (String?, optionnel par item) — prioritaire sur [senderName]
///   - 'sentAt'     (int?, ms depuis epoch, optionnel par item) — prioritaire sur [sentAt]
class AlbumSwipeViewer extends StatefulWidget {
  final List<Map<String, dynamic>> medias;
  final int initialIndex;
  final String? senderName; // fallback si l'item n'a pas 'senderName'
  final DateTime? sentAt; // fallback si l'item n'a pas 'sentAt'

  const AlbumSwipeViewer({
    super.key,
    required this.medias,
    required this.initialIndex,
    this.senderName,
    this.sentAt,
  });

  @override
  State<AlbumSwipeViewer> createState() => _AlbumSwipeViewerState();
}

class _AlbumSwipeViewerState extends State<AlbumSwipeViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  Future<void> _download() async {
    if (_downloading) return;
    final item = widget.medias[_currentIndex];
    final url = item['url'] as String? ?? '';
    final isVideo = ((item['mimeType'] as String?) ?? '').startsWith('video/');
    setState(() => _downloading = true);
    if (isVideo) {
      await MediaDownloader.downloadVideo(context, url);
    } else {
      await MediaDownloader.downloadImage(context, url);
    }
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.medias.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final item = widget.medias[index];
              final url = item['url'] as String? ?? '';
              final mimeType = (item['mimeType'] as String?) ?? '';
              if (mimeType.startsWith('video/')) {
                return SwipeVideoPage(
                  key: ValueKey(url),
                  url: url,
                  isActive: index == _currentIndex,
                  showControls: _showControls,
                  onTap: () => setState(() => _showControls = !_showControls),
                );
              }
              return SwipeImagePage(
                url: url,
                onTap: () => setState(() => _showControls = !_showControls),
              );
            },
          ),

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
                        child: Builder(
                          builder: (_) {
                            final cur = widget.medias[_currentIndex];
                            final name =
                                cur['senderName'] as String? ??
                                widget.senderName;
                            final sentAtMs = cur['sentAt'] as int?;
                            final sentAt = sentAtMs != null
                                ? DateTime.fromMillisecondsSinceEpoch(sentAtMs)
                                : widget.sentAt;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (name?.isNotEmpty == true)
                                  Text(
                                    name!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (sentAt != null)
                                  Text(
                                    viewerFormatDateTime(sentAt),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      Text(
                        '${_currentIndex + 1} / ${widget.medias.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
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
        ],
      ),
    );
  }
}
