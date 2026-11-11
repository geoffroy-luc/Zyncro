import 'package:flutter/material.dart';
import 'package:zyncro/features/groups/domain/entities/group.dart';
import 'package:zyncro/features/groups/presentation/widgets/groups_empty_hint.dart';
import 'package:zyncro/features/groups/presentation/widgets/groups_group_tile.dart';

// ── Group list ───────────────────────────────────────────────────────────────

class GroupList extends StatelessWidget {
  final List<Group> groups;
  final ValueChanged<Group> onGroupTap;
  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;
  final void Function(int oldIndex, int newIndex) onReorder;

  const GroupList({
    super.key,
    required this.groups,
    required this.onGroupTap,
    required this.onCreateTap,
    required this.onJoinTap,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GroupsEmptyHint(onCreateTap: onCreateTap, onJoinTap: onJoinTap),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: onReorder,
            proxyDecorator: (child, index, animation) =>
                Material(color: Colors.transparent, child: child),
            children: [
              for (var i = 0; i < groups.length; i++)
                ReorderableDelayedDragStartListener(
                  key: ValueKey(groups[i].id),
                  index: i,
                  child: GroupsGroupTile(
                    group: groups[i],
                    onTap: () => onGroupTap(groups[i]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCreateTap,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Créer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onJoinTap,
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: const Text('Rejoindre'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
