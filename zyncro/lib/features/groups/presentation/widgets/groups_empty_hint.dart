import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

class GroupsEmptyHint extends StatelessWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;

  const GroupsEmptyHint({
    super.key,
    required this.onCreateTap,
    required this.onJoinTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 40,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.groupsAucunEspace,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.groupsCreeOuRejoinsUnEspace,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.groupsCreerUnEspace),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onJoinTap,
              icon: const Icon(Icons.group_add_outlined),
              label: Text(context.l10n.groupsRejoindreAvecUnCode),
            ),
          ],
        ),
      ),
    );
  }
}
