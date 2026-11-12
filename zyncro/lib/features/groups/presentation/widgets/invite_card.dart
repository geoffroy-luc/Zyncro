import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/groups/domain/repositories/groups_repository.dart';
import 'package:zyncro/features/groups/presentation/widgets/emoji_avatar.dart';

class InviteCard extends StatelessWidget {
  final InvitePreview preview;
  final bool alreadyMember;
  final bool joining;
  final String? error;
  final VoidCallback onJoin;
  final VoidCallback onOpen;

  const InviteCard({
    super.key,
    required this.preview,
    required this.alreadyMember,
    required this.joining,
    required this.error,
    required this.onJoin,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = preview.groupName;
    final emoji = preview.groupEmoji;
    final photoUrl = preview.groupPhotoUrl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: context.colors.primary.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: (photoUrl != null && photoUrl.isNotEmpty)
              ? Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      EmojiAvatar(emoji: emoji, name: name),
                )
              : EmojiAvatar(emoji: emoji, name: name),
        ),
        const SizedBox(height: 24),
        Text(
          alreadyMember
              ? 'Tu fais déjà partie de'
              : 'Tu as été invité·e à rejoindre',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          name?.isNotEmpty == true ? name! : 'un espace Zyncro',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (error != null) ...[
          Text(
            error!,
            style: TextStyle(color: context.colors.error, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          child: alreadyMember
              ? ElevatedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.login),
                  label: Text(context.l10n.groupsOuvrirCetEspace),
                )
              : ElevatedButton(
                  onPressed: joining ? null : onJoin,
                  child: joining
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(context.l10n.groupsRejoindre),
                ),
        ),
      ],
    );
  }
}
