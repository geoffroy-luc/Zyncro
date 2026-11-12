import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zyncro/core/constants/app_colors.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/features/notes/domain/entities/note.dart';

Color notesHexToColor(String? hex) {
  if (hex == null) return AppColors.secondary;
  return hexToColor(hex);
}

String notesFormatDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'Hier';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
  return DateFormat('d MMM', 'fr_FR').format(dt);
}

// ── Aperçu checklist ──────────────────────────────────────────────────────────

Widget notesBuildChecklistPreview(
  List<ChecklistItem> items,
  Color accentColor, {
  int maxItems = 3,
  double fontSize = 11,
}) {
  final done = items.where((i) => i.done).length;
  final total = items.length;
  final display = items.take(maxItems).toList();
  final remaining = total - display.length;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Barre de progression
      if (total > 0) ...[
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? done / total : 0,
                  minHeight: 4,
                  backgroundColor: accentColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$done/$total',
              style: TextStyle(
                fontSize: fontSize - 1,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
      // Items
      ...display.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            children: [
              Icon(
                item.done
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: fontSize + 1,
                color: item.done ? accentColor : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.text,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: item.done
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    decoration: item.done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      if (remaining > 0)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '+ $remaining autre${remaining > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: fontSize - 1,
              color: AppColors.textSecondary,
            ),
          ),
        ),
    ],
  );
}
