import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/groups/domain/entities/group_member.dart';

class ReactionsRow extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final String? currentUserId;
  final List<GroupMember> members;

  const ReactionsRow({
    super.key,
    required this.reactions,
    this.currentUserId,
    this.members = const [],
  });

  void _showReactionDetails(BuildContext context) {
    final entries = reactions.entries.where((e) => e.value.isNotEmpty).toList();
    final nameByUid = {for (final m in members) m.uid: m.displayName};

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Réactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ...entries.map((e) {
                final emoji = e.key;
                final uids = e.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          '${uids.length}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...uids.map((uid) {
                      final name = uid == currentUserId
                          ? 'Vous'
                          : (nameByUid[uid] ?? uid);
                      return Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = reactions.entries.where((e) => e.value.isNotEmpty).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: entries.map((e) {
        final emoji = e.key;
        final users = e.value;
        final isMine = currentUserId != null && users.contains(currentUserId);

        return GestureDetector(
          onTap: () => _showReactionDetails(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isMine
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.15)
                  : context.colors.mutedSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMine
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.4)
                    : context.colors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 3),
                Text(
                  '${users.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isMine
                        ? darken(Theme.of(context).colorScheme.primary)
                        : context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
