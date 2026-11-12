import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';
import 'package:zyncro/features/dashboard/presentation/widgets/dashboard_screen_helpers.dart';
import 'package:zyncro/features/groups/domain/entities/group_member.dart';
import 'package:zyncro/shared/widgets/user_avatar.dart';

class MessageRow extends StatelessWidget {
  final Message message;
  final bool isMe;
  final Map<String, String> memberNames;
  final List<GroupMember> members;
  const MessageRow({
    super.key,
    required this.message,
    required this.isMe,
    required this.memberNames,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedName = isMe
        ? 'Vous'
        : (memberNames[message.senderId] ?? message.senderName ?? '?');
    final name = resolvedName;
    final member = members.where((m) => m.uid == message.senderId).firstOrNull;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(
          photoUrl: member?.photoUrl,
          showPhoto: member?.showProfilePhoto ?? true,
          displayName: isMe ? 'Vous' : resolvedName,
          radius: 18,
          color: avatarColorForUid(message.senderId ?? ''),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dashboardTimeAgo(message.timestamp),
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                message.type == MessageType.image
                    ? 'a envoyé une photo'
                    : message.type == MessageType.file
                    ? 'a envoyé un fichier'
                    : message.type == MessageType.audio
                    ? 'a envoyé un audio'
                    : message.type == MessageType.poll
                    ? 'a créé un sondage'
                    : message.content,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
