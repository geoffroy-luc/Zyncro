import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class AssetThumbnail extends StatefulWidget {
  final AssetEntity asset;
  const AssetThumbnail({super.key, required this.asset});

  @override
  State<AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<AssetThumbnail> {
  Uint8List? _bytes;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.asset
          .thumbnailDataWithSize(const ThumbnailSize.square(200))
          .then((bytes) {
            if (mounted) setState(() => _bytes = bytes);
          })
          .catchError((_) {
            if (mounted) setState(() => _error = true);
          }),
    );
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
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.white38,
            ),
          ),
        ),
      );
    }
    return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
  }
}
