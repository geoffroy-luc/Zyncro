import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

class GalleryVideoThumb extends StatelessWidget {
  final String url;
  const GalleryVideoThumb({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.mediaBackground,
      child: const Center(
        child: Icon(
          Icons.play_circle_fill_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}
