import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/chat/presentation/widgets/media_downloader.dart';
import 'package:zyncro/features/chat/presentation/widgets/media_viewer_helpers.dart';

// ── Image fullscreen ──────────────────────────────────────────────────────────

class ImageViewerScreen extends StatefulWidget {
  final String url;
  final String? senderName;
  final DateTime? sentAt;

  const ImageViewerScreen({
    super.key,
    required this.url,
    this.senderName,
    this.sentAt,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _showControls = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    await MediaDownloader.downloadImage(context, widget.url);
    if (mounted) setState(() => _downloading = false);
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
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 64,
                  ),
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
                            tooltip: context.l10n.chatEnregistrer,
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
