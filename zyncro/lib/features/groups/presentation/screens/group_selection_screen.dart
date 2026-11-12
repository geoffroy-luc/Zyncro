import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zyncro/core/navigation/app_routes.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/groups/presentation/widgets/create_group_sheet.dart';
import 'package:zyncro/features/groups/presentation/widgets/group_list.dart';
import 'package:zyncro/features/groups/presentation/widgets/groups_error_view.dart';
import 'package:zyncro/features/groups/presentation/widgets/join_group_sheet.dart';

class GroupSelectionScreen extends ConsumerWidget {
  const GroupSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Mes espaces'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Mon profil',
            onPressed: () => context.push(AppRoutes.profile),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => GroupsErrorView(
          error: e,
          onRetry: () => ref.invalidate(userGroupsProvider),
        ),
        data: (_) {
          final groups = ref.watch(orderedGroupsProvider);
          return GroupList(
            groups: groups,
            onGroupTap: (group) async {
              final userId = ref.read(authStateProvider).asData?.value?.uid;
              if (userId != null) {
                unawaited(
                  ref
                      .read(messagesRepositoryProvider)
                      .markGroupAsRead(groupId: group.id, userId: userId),
                );
              }
              await ref.read(selectedGroupIdProvider.notifier).select(group.id);
              if (context.mounted) context.go(AppRoutes.home);
            },
            onCreateTap: () => _showCreateSheet(context, ref),
            onJoinTap: () => _showJoinSheet(context, ref),
            onReorder: (oldIndex, newIndex) {
              final ids = groups.map((g) => g.id).toList();
              if (newIndex > oldIndex) newIndex--;
              final moved = ids.removeAt(oldIndex);
              ids.insert(newIndex, moved);
              unawaited(ref.read(groupOrderProvider.notifier).reorder(ids));
            },
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CreateGroupSheet(ref: ref),
      ),
    );
  }

  void _showJoinSheet(BuildContext context, WidgetRef ref) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => JoinGroupSheet(ref: ref),
      ),
    );
  }
}
