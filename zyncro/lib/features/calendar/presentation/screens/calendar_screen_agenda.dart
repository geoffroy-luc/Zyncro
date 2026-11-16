part of 'calendar_screen.dart';

/// Navigation entre mois et sections de la vue agenda.
mixin _CalendarNavigation on _CalendarScreenStateBase {
  void _prevMonth() => setState(() {
    _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    _selectedDay = null;
    _monthStep = -1;
  });

  void _nextMonth() => setState(() {
    _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    _selectedDay = null;
    _monthStep = 1;
  });

  List<Widget> _buildAgendaSections(List<Event> events, Color primaryColor) {
    final now = DateTime.now();
    final Map<DateTime, List<Event>> grouped = {};
    for (final e in events) {
      final day = DateTime(
        e.startDate.year,
        e.startDate.month,
        e.startDate.day,
      );
      grouped.putIfAbsent(day, () => []).add(e);
    }
    final sortedDays = grouped.keys.toList()..sort();
    final today = DateTime.now();
    final widgets = <Widget>[];

    for (final day in sortedDays) {
      final isToday = isSameDay(day, today);
      final isTomorrow = isSameDay(
        day,
        DateTime(today.year, today.month, today.day + 1),
      );

      final label = isToday
          ? "Aujourd'hui"
          : isTomorrow
          ? 'Demain'
          : DateFormat('EEEE d MMMM', 'fr_FR').format(day);

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: isToday
                      ? LinearGradient(
                          colors: [primaryColor, darken(primaryColor)],
                        )
                      : null,
                  color: isToday
                      ? null
                      : isTomorrow
                      ? const Color(0x1A2BB8A5)
                      : context.colors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isToday
                        ? Colors.white
                        : isTomorrow
                        ? context.colors.secondary
                        : context.colors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...grouped[day]!.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  // Événement terminé : estompé, comme dans la vue mois.
                  child: isPastEvent(e, now)
                      ? Opacity(opacity: 0.6, child: AgendaEventCard(event: e))
                      : AgendaEventCard(event: e),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}
