import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';
import 'package:zyncro/features/chat/presentation/screens/media_viewer_screen.dart';
import 'package:zyncro/features/chat/presentation/widgets/audio_player_widget.dart';
import 'package:zyncro/features/chat/presentation/widgets/link_preview_widget.dart';
import 'package:zyncro/features/chat/presentation/widgets/linked_text.dart';
import 'package:zyncro/features/chat/presentation/widgets/media_album_bubble.dart';
import 'package:zyncro/features/chat/presentation/widgets/poll_card.dart';
import 'package:zyncro/features/chat/presentation/widgets/reactions_row.dart';
import 'package:zyncro/features/chat/presentation/widgets/reply_preview.dart';
import 'package:zyncro/features/chat/presentation/widgets/video_thumbnail.dart';
import 'package:zyncro/features/groups/domain/entities/group_member.dart';
import 'package:zyncro/shared/widgets/user_avatar.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? currentUserId;
  final bool showTimestamp;
  final bool showAvatar;
  final bool showSenderName;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final GroupMember? member;
  final List<GroupMember> members;
  final String? resolvedReplyContent;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(int)? onVote;
  final VoidCallback? onReplyPreviewTap;
  final bool hasCustomBackground;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.showTimestamp,
    required this.showAvatar,
    required this.showSenderName,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    this.member,
    this.members = const [],
    this.currentUserId,
    this.resolvedReplyContent,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onVote,
    this.onReplyPreviewTap,
    this.hasCustomBackground = false,
  });

  static final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);

  static String cleanUrl(String url) =>
      url.replaceAll(RegExp(r'[.,;:!?)\]>]+$'), '');

  static Future<void> openUrl(String raw) async {
    final url = cleanUrl(raw);
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Widget _messageContent(BuildContext context, bool isMe) {
    if (message.type == MessageType.audio) {
      try {
        final data = jsonDecode(message.content) as Map<String, dynamic>;
        return AudioPlayerWidget(
          key: ValueKey(message.id),
          url: data['url'] as String? ?? '',
          durationSeconds: (data['duration'] as num?)?.toInt() ?? 0,
          isMe: isMe,
        );
      } catch (_) {
        return Text(
          '🎵 Audio',
          style: TextStyle(
            color: isMe ? Colors.white : context.colors.textPrimary,
            fontSize: 14,
          ),
        );
      }
    }
    if (message.type == MessageType.image || message.type == MessageType.file) {
      try {
        final data = jsonDecode(message.content) as Map<String, dynamic>;
        // Album multi-médias
        if (data.containsKey('medias')) {
          final medias = (data['medias'] as List<dynamic>)
              .map((e) => e as Map<String, dynamic>)
              .toList();
          return MediaAlbumBubble(
            medias: medias,
            isMe: isMe,
            senderName: message.senderName,
            sentAt: message.timestamp,
          );
        }
        // Média unique (rétrocompatibilité)
        final url = data['url'] as String? ?? '';
        final mimeType = (data['mimeType'] as String?) ?? '';
        if (mimeType.startsWith('video/') || message.type == MessageType.file) {
          return GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => VideoViewerScreen(
                  url: url,
                  senderName: message.senderName,
                  sentAt: message.timestamp,
                ),
              ),
            ),
            child: VideoThumbnail(key: ValueKey(message.id), url: url),
          );
        }
        return GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => ImageViewerScreen(
                url: url,
                senderName: message.senderName,
                sentAt: message.timestamp,
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 220,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : SizedBox(
                      width: 220,
                      height: 160,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                              : null,
                          color: isMe
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
              errorBuilder: (_, __, ___) => Text(
                '🖼️ Image',
                style: TextStyle(
                  color: isMe ? Colors.white : context.colors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      } catch (_) {
        return Text(
          '🖼️ Média',
          style: TextStyle(
            color: isMe ? Colors.white : context.colors.textPrimary,
            fontSize: 14,
          ),
        );
      }
    }
    final urls = urlRegex
        .allMatches(message.content)
        .map((m) => cleanUrl(m.group(0)!))
        .where((u) => u.isNotEmpty)
        .toList();

    final textWidget = LinkedText(text: message.content, isMe: isMe);

    if (urls.isEmpty) return textWidget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        textWidget,
        const SizedBox(height: 8),
        LinkPreviewWidget(url: urls.first, isMe: isMe),
      ],
    );
  }

  String _formatTime(DateTime dt) => DateFormat('HH:mm').format(dt);

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.poll) {
      return PollCard(
        message: message,
        isMe: isMe,
        currentUserId: currentUserId,
        onVote: onVote,
        onLongPress: onLongPress,
      );
    }

    if (message.type == MessageType.system) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: hasCustomBackground
                  ? Colors.black
                  : context.colors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final timeLabel = message.editedAt == null
        ? _formatTime(message.timestamp)
        : '${_formatTime(message.timestamp)} · modifié';

    final reactionsRow = message.reactions.isNotEmpty
        ? ReactionsRow(
            reactions: message.reactions,
            currentUserId: currentUserId,
            members: members,
          )
        : null;

    // ── Timestamp flottant (visible au tap) ──────────────────────────
    final timestampWidget = showTimestamp
        ? Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Center(
              child: Text(
                timeLabel,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          )
        : null;

    final isMedia =
        message.type == MessageType.image || message.type == MessageType.file;

    if (isMe) {
      // Border radius selon position dans le groupe
      final radius = BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: Radius.circular(isLastInGroup ? 16 : 4),
        bottomLeft: const Radius.circular(16),
        bottomRight: Radius.circular(isFirstInGroup ? 4 : 4),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (timestampWidget != null) timestampWidget,
          GestureDetector(
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onLongPress: onLongPress,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: isMedia
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMedia
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          darken(Theme.of(context).colorScheme.primary),
                        ],
                      ),
                borderRadius: radius,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.replyToContent != null)
                    ReplyPreview(
                      senderName: message.replyToSenderName,
                      content: resolvedReplyContent ?? message.replyToContent!,
                      isMe: true,
                      onTap: onReplyPreviewTap,
                    ),
                  _messageContent(context, true),
                ],
              ),
            ),
          ),
          if (reactionsRow != null) ...[
            const SizedBox(height: 4),
            reactionsRow,
          ],
        ],
      );
    }

    // ── Message reçu ────────────────────────────────────────────────
    final avatarColor = avatarColorForUid(message.senderId ?? '');

    final radius = BorderRadius.only(
      topLeft: Radius.circular(isLastInGroup ? 16 : 4),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isFirstInGroup ? 16 : 4),
      bottomRight: const Radius.circular(16),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSenderName)
          Padding(
            padding: const EdgeInsets.only(left: 46, bottom: 2),
            child: Text(
              member?.displayName ?? message.senderName ?? '',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        if (timestampWidget != null) timestampWidget,
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar ou placeholder pour maintenir l'alignement
            if (showAvatar)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: UserAvatar(
                  photoUrl: member?.photoUrl,
                  showPhoto: member?.showProfilePhoto ?? true,
                  displayName: member?.displayName ?? message.senderName ?? '?',
                  radius: 15,
                  color: avatarColor,
                ),
              )
            else
              const SizedBox(width: 38),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  onDoubleTap: onDoubleTap,
                  onLongPress: onLongPress,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    padding: isMedia
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: radius,
                      border: isMedia
                          ? null
                          : Border.all(color: context.colors.border),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.shadow,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.replyToContent != null)
                          ReplyPreview(
                            senderName: message.replyToSenderName,
                            content:
                                resolvedReplyContent ?? message.replyToContent!,
                            isMe: false,
                            onTap: onReplyPreviewTap,
                          ),
                        _messageContent(context, false),
                      ],
                    ),
                  ),
                ),
                if (reactionsRow != null) ...[
                  const SizedBox(height: 4),
                  reactionsRow,
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}
