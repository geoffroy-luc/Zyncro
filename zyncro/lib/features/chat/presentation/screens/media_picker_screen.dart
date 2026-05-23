import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

typedef MediaPickerResult = List<({String path, String mimeType})>;

class MediaPickerScreen extends StatefulWidget {
  final int maxCount;

  const MediaPickerScreen({super.key, this.maxCount = 10});

  @override
  State<MediaPickerScreen> createState() => _MediaPickerScreenState();
}

class _MediaPickerScreenState extends State<MediaPickerScreen> {
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  bool _loading = true;
  bool _permissionDenied = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      if (mounted) setState(() { _loading = false; _permissionDenied = true; });
      return;
    }

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );
    if (paths.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final assets = await paths.first.getAssetListPaged(page: 0, size: 300);
    if (mounted) setState(() { _assets = assets; _loading = false; });
  }

  void _toggle(AssetEntity asset) {
    setState(() {
      if (_selected.contains(asset)) {
        _selected.remove(asset);
      } else if (_selected.length < widget.maxCount) {
        _selected.add(asset);
      }
    });
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty || _confirming) return;
    setState(() => _confirming = true);

    final result = <({String path, String mimeType})>[];
    for (final asset in _selected) {
      final file = await asset.originFile;
      if (file != null) {
        final mimeType = asset.mimeType ??
            (asset.type == AssetType.video ? 'video/mp4' : 'image/jpeg');
        result.add((path: file.path, mimeType: mimeType));
      }
    }

    if (mounted) Navigator.of(context).pop(result);
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _selected.isEmpty
              ? 'Galerie'
              : '${_selected.length} / ${widget.maxCount}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _confirming
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: _confirm,
                      child: Text(
                        'Envoyer (${_selected.length})',
                        style: const TextStyle(
                          color: Color(0xFFE85D75),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE85D75)),
            )
          : _permissionDenied
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline,
                          color: Colors.white54, size: 52),
                      const SizedBox(height: 16),
                      const Text(
                        'Accès à la galerie refusé',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: PhotoManager.openSetting,
                        child: const Text(
                          'Ouvrir les réglages',
                          style: TextStyle(color: Color(0xFFE85D75)),
                        ),
                      ),
                    ],
                  ),
                )
          : _assets.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun média',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 1.5,
                    crossAxisSpacing: 1.5,
                  ),
                  itemCount: _assets.length,
                  itemBuilder: (context, index) {
                    final asset = _assets[index];
                    final selIdx = _selected.indexOf(asset);
                    final isSelected = selIdx >= 0;
                    final maxReached = _selected.length >= widget.maxCount;

                    return GestureDetector(
                      onTap: () {
                        if (!isSelected && maxReached) return;
                        _toggle(asset);
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Thumbnail
                          _AssetThumbnail(asset: asset),

                          // Overlay grisé si quota atteint et non sélectionné
                          if (!isSelected && maxReached)
                            Container(
                              color: Colors.black.withValues(alpha: 0.5),
                            ),

                          // Overlay sombre si sélectionné
                          if (isSelected)
                            Container(
                              color: Colors.black.withValues(alpha: 0.2),
                            ),

                          // Durée vidéo en bas à gauche
                          if (asset.type == AssetType.video)
                            Positioned(
                              bottom: 5,
                              left: 5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam,
                                        color: Colors.white, size: 11),
                                    const SizedBox(width: 2),
                                    Text(
                                      _fmtDuration(asset.videoDuration),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Badge de sélection (cercle haut-droite)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE85D75)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Text(
                                        '${selIdx + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _AssetThumbnail extends StatefulWidget {
  final AssetEntity asset;
  const _AssetThumbnail({required this.asset});

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  Uint8List? _bytes;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    widget.asset
        .thumbnailDataWithSize(const ThumbnailSize.square(200))
        .then((bytes) {
          if (mounted) setState(() => _bytes = bytes);
        })
        .catchError((_) {
          if (mounted) setState(() => _error = true);
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_error || (_bytes != null && _bytes!.isEmpty)) {
      return Container(
        color: Colors.grey[900],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
    final bytes = _bytes;
    if (bytes == null) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white38),
          ),
        ),
      );
    }
    return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
  }
}
