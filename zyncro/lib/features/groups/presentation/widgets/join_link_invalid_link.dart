import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

class JoinLinkInvalidLink extends StatelessWidget {
  final VoidCallback onClose;
  const JoinLinkInvalidLink({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.link_off_rounded,
          size: 64,
          color: context.colors.textSecondary,
        ),
        const SizedBox(height: 20),
        Text(
          context.l10n.groupsLienInvalide,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.groupsInvalidInviteLinkBody,
          style: TextStyle(color: context.colors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onClose,
            child: Text(context.l10n.groupsFermer),
          ),
        ),
      ],
    );
  }
}
