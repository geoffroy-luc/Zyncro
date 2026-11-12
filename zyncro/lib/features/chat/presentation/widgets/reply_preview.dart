import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/chat/presentation/widgets/reply_kind_label.dart';

// ── Reply preview (dans la bulle) ────────────────────────────────────────────

class ReplyPreview extends StatelessWidget {
  final String? senderName;
  final String content;
  final bool isMe;
  final VoidCallback? onTap;

  const ReplyPreview({
    super.key,
    required this.content,
    required this.isMe,
    this.senderName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.2)
              : context.colors.mutedSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.7)
                  : Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (senderName != null)
              Text(
                senderName!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.9)
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            Text(
              replyLabel(context, content),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.75)
                    : context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
