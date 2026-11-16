import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';

/// Suite d'activités de l'espace (« 📝 X a créé une note… ») repliée en une
/// seule ligne, dépliable : la conversation n'est pas noyée.
class ActivityGroupTile extends StatelessWidget {
  const ActivityGroupTile({
    super.key,
    required this.activities,
    required this.expanded,
    required this.onToggle,
    required this.hasCustomBackground,
  });

  /// Du plus récent au plus ancien (ordre de la liste du chat).
  final List<Message> activities;
  final bool expanded;
  final VoidCallback onToggle;
  final bool hasCustomBackground;

  @override
  Widget build(BuildContext context) {
    final textColor = hasCustomBackground
        ? Colors.black
        : context.colors.textSecondary;
    final pillColor = context.colors.border.withValues(alpha: 0.5);
    // Emojis de tête des activités (📝, 📅, 💰, 👋…), sans doublon.
    final icons = <String>{
      for (final a in activities)
        if (a.content.characters.isNotEmpty) a.content.characters.first,
    }.take(4).join(' ');

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: pillColor,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icons.isNotEmpty) ...[
                    Text(icons, style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    context.l10n.chatActivites(activities.length),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, size: 16, color: textColor),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      children: [
                        // Ordre chronologique, de haut en bas.
                        for (final a in activities.reversed)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              a.content,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textColor, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
