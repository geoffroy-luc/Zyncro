import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/notes/domain/entities/note.dart';
import 'package:zyncro/features/notes/presentation/widgets/notes_screen_helpers.dart';

// ── Carte récente (grille 2 colonnes) ────────────────────────────────────────

class RecentNoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  const RecentNoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final color = notesHexToColor(note.color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bande couleur
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icône + bouton épingler
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            note.isChecklist
                                ? Icons.checklist_rounded
                                : Icons.description_outlined,
                            size: 15,
                            color: color,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onTogglePin,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              note.isPinned
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                              size: 16,
                              color: note.isPinned
                                  ? context.colors.accent
                                  : context.colors.textSecondary.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Titre
                    Text(
                      note.title,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Contenu
                    Expanded(
                      child: note.isChecklist && note.checklist.isNotEmpty
                          ? ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                maxHeight: double.infinity,
                                child: notesBuildChecklistPreview(
                                  context,
                                  note.checklist,
                                  color,
                                ),
                              ),
                            )
                          : Text(
                              note.content,
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 11,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    const SizedBox(height: 6),
                    // Date
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 11,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          notesFormatDate(note.updatedAt),
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
