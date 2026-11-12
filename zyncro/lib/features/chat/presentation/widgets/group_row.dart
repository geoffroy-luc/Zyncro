import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/groups/domain/entities/group.dart';

// ── Ligne de groupe ──────────────────────────────────────────────────────────

class GroupRow extends StatelessWidget {
  final Group group;
  final bool selected;
  final VoidCallback? onTap;

  const GroupRow({
    super.key,
    required this.group,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: selected
            ? context.colors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: group.photoUrl != null
                  ? Image.network(
                      group.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    )
                  : Center(
                      child: Text(
                        group.emoji?.isNotEmpty == true
                            ? group.emoji!
                            : (group.name.isNotEmpty
                                  ? group.name[0].toUpperCase()
                                  : '?'),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                group.name,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? context.colors.primary : context.colors.border,
            ),
          ],
        ),
      ),
    );
  }
}
