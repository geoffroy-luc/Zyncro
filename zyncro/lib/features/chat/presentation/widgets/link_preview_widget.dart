import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/chat/domain/entities/link_meta.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';

// ── Prévisualisation de lien ─────────────────────────────────────────────────

class LinkPreviewWidget extends ConsumerStatefulWidget {
  final String url;
  final bool isMe;

  const LinkPreviewWidget({super.key, required this.url, required this.isMe});

  @override
  ConsumerState<LinkPreviewWidget> createState() => _LinkPreviewWidgetState();
}

class _LinkPreviewWidgetState extends ConsumerState<LinkPreviewWidget> {
  LinkMeta? _meta;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_fetchMeta());
  }

  Future<void> _fetchMeta() async {
    final meta = await ref.read(linkPreviewServiceProvider).fetch(widget.url);
    if (mounted) {
      setState(() {
        _meta = meta;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    final meta = _meta;
    if (meta == null ||
        (meta.title == null &&
            meta.description == null &&
            meta.imageUrl == null)) {
      return const SizedBox.shrink();
    }
    return _buildCard(meta);
  }

  Widget _buildLoading() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withValues(alpha: 0.15)
            : context.colors.subtleSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: widget.isMe
                ? Colors.white54
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(LinkMeta meta) {
    final isMe = widget.isMe;
    final borderColor = isMe
        ? Colors.white.withValues(alpha: 0.6)
        : Theme.of(context).colorScheme.primary;
    final bgColor = isMe
        ? Colors.white.withValues(alpha: 0.18)
        : context.colors.subtleSurface;
    final titleColor = isMe ? Colors.white : context.colors.textPrimary;
    final subColor = isMe ? Colors.white70 : context.colors.textSecondary;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(widget.url);
        if (uri != null) {
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {}
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: borderColor, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (meta.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(8),
                ),
                child: Image.network(
                  meta.imageUrl!,
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (meta.siteName != null)
                    Text(
                      meta.siteName!,
                      style: TextStyle(
                        color: subColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (meta.title != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta.title!,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (meta.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta.description!,
                      style: TextStyle(color: subColor, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
