import 'dart:io';

import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/chat/presentation/providers/share_provider.dart';

// ── Aperçu du contenu partagé ────────────────────────────────────────────────

class SharePreview extends StatelessWidget {
  final PendingShare share;
  const SharePreview({super.key, required this.share});

  @override
  Widget build(BuildContext context) {
    if (share.kind == SharedKind.text) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: context.colors.surface,
        child: Text(
          share.text ?? '',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: context.colors.surface,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: share.medias.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final m = share.medias[i];
            final isImage = m.mimeType.startsWith('image/');
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 88,
                height: 88,
                child: isImage
                    ? Image.file(File(m.path), fit: BoxFit.cover)
                    : Container(
                        color: Colors.black12,
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 34,
                          color: context.colors.textSecondary,
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
