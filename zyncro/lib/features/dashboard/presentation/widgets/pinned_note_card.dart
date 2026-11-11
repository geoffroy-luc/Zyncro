import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/dashboard/presentation/widgets/dashboard_screen_helpers.dart';
import 'package:zyncro/features/notes/domain/entities/note.dart';

class PinnedNoteCard extends StatelessWidget {
  final Note note;
  final Color color;
  const PinnedNoteCard({super.key, required this.note, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.05),
            color.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.sticky_note_2, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Text(
                  'Note épinglée',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Icon(Icons.push_pin, size: 16, color: context.colors.accent),
              ],
            ),
          ),
          Divider(height: 1, color: color.withValues(alpha: 0.2)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                if (note.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    note.content,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Modifié ${dashboardTimeAgo(note.updatedAt)}',
                  style: TextStyle(color: color, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
