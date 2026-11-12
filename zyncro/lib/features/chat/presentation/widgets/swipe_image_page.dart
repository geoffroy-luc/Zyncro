import 'package:flutter/material.dart';

// ── Page image dans le swipe viewer ──────────────────────────────────────────

class SwipeImagePage extends StatelessWidget {
  final String url;
  final VoidCallback onTap;

  const SwipeImagePage({super.key, required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Image.network(
          url,
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
    );
  }
}
