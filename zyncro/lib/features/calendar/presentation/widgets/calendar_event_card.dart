import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/calendar/domain/entities/event.dart';
import 'package:zyncro/features/calendar/presentation/screens/event_form_screen.dart';
import 'package:zyncro/features/calendar/presentation/widgets/calendar_screen_helpers.dart';

class CalendarEventCard extends ConsumerWidget {
  final Event event;
  const CalendarEventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = calendarEventColor(event);

    void openEdit() {
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EventFormScreen(event: event),
          ),
        ),
      );
    }

    final cardContent = GestureDetector(
      onTap: openEdit,
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (event.recurrence != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.repeat,
                            size: 14,
                            color: context.colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: context.colors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        event.endDate != null
                            ? '${calendarTimeLabel(event.startDate)} → ${calendarTimeLabel(event.endDate!)}'
                            : calendarTimeLabel(event.startDate),
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (event.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.location!,
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (event.creatorName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          event.creatorName!,
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.edit_outlined,
              size: 16,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );

    return cardContent;
  }
}
