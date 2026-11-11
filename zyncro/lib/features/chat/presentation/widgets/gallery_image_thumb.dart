import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

class GalleryImageThumb extends StatelessWidget {
  final String url;
  const GalleryImageThumb({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: context.colors.border,
        child: Icon(
          Icons.broken_image_outlined,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}
