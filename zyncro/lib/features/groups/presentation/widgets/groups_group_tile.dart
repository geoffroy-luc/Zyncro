import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/groups/domain/entities/group.dart';

class GroupsGroupTile extends ConsumerWidget {
  final Group group;
  final VoidCallback onTap;

  const GroupsGroupTile({super.key, required this.group, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unreadCount =
        ref.watch(unreadCountProvider(group.id)).asData?.value ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: group.photoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              group.photoUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          )
                        : Center(
                            child: Text(
                              group.emoji?.isNotEmpty == true
                                  ? group.emoji!
                                  : group.name[0].toUpperCase(),
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.accent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 20),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: theme.textTheme.titleMedium),
                    if (group.description != null)
                      Text(
                        group.description!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      context.l10n.commonMemberCount(group.memberIds.length),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.colors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (group.inviteCode != null)
                GestureDetector(
                  onTap: () {
                    unawaited(
                      Clipboard.setData(ClipboardData(text: group.inviteCode!)),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.groupsCodeCopie('${group.inviteCode}'),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      group.inviteCode!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.colors.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: context.colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
