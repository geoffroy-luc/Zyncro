import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/calendar/domain/entities/event.dart';
import 'package:zyncro/features/dashboard/presentation/widgets/dashboard_screen_helpers.dart';

class EventRow extends StatelessWidget {
  final Event event;
  const EventRow({super.key, required this.event});

  Color _parseEventColor() =>
      tryHexToColor(event.color) ?? const Color(0xFF4F7CFF);

  @override
  Widget build(BuildContext context) {
    final isToday = dashboardIsToday(event.startDate);

    final baseColor = _parseEventColor();
    final colorPair = [
      baseColor,
      Color.fromARGB(
        (baseColor.a * 255.0).round() & 0xff,
        ((baseColor.r * 255.0).round() & 0xff) * 4 ~/ 5,
        ((baseColor.g * 255.0).round() & 0xff) * 4 ~/ 5,
        ((baseColor.b * 255.0).round() & 0xff) * 4 ~/ 5,
      ),
    ];

    String dateLabel;
    if (isToday) {
      dateLabel =
          "Aujourd'hui • ${DateFormat('HH:mm').format(event.startDate)}";
    } else {
      dateLabel = DateFormat('d MMM • HH:mm', 'fr_FR').format(event.startDate);
    }

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colorPair,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colorPair.first.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat(
                  'MMM',
                  'fr_FR',
                ).format(event.startDate).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${event.startDate.day}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                dateLabel,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
