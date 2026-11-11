import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/groups/domain/entities/group_member.dart';
import 'package:zyncro/shared/widgets/user_avatar.dart';

// ── Seen-by row (petites PP sous le dernier message lu) ─────────────────────
class SeenByRow extends StatelessWidget {
  final List<GroupMember> members;

  const SeenByRow({super.key, required this.members});

  static const int _maxVisible = 6;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(_maxVisible).toList();
    final overflow = members.length - _maxVisible;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visible.map(
          (m) => Padding(
            padding: const EdgeInsets.only(left: 2),
            child: UserAvatar(
              photoUrl: m.photoUrl,
              showPhoto: m.showProfilePhoto,
              displayName: m.displayName,
              radius: 7,
              color: avatarColorForUid(m.uid),
            ),
          ),
        ),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '+$overflow',
              style: TextStyle(
                fontSize: 10,
                color: context.colors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
