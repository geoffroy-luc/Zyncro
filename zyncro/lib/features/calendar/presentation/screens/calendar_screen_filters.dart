part of 'calendar_screen.dart';

/// Feuille de filtres et application des filtres.
mixin _CalendarFilterActions on _CalendarScreenStateBase {
  Future<void> _showFilterSheet(
    List<GroupMember> members,
    Color primaryColor,
  ) async {
    final tempParticipants = List<String>.from(_filterParticipantIds);
    final tempRecurrence = [_filterRecurrenceOnly];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.calendarFiltres,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  if (tempParticipants.isNotEmpty || tempRecurrence[0])
                    TextButton(
                      onPressed: () => setSheet(() {
                        tempParticipants.clear();
                        tempRecurrence[0] = false;
                      }),
                      child: Text(
                        context.l10n.calendarReinitialiser,
                        style: TextStyle(color: context.colors.error),
                      ),
                    ),
                ],
              ),
              if (members.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  context.l10n.calendarParticipants,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: members.map((m) {
                    final sel = tempParticipants.contains(m.uid);
                    return FilterChip(
                      label: Text(
                        m.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          color: sel
                              ? Colors.white
                              : context.colors.textPrimary,
                        ),
                      ),
                      selected: sel,
                      onSelected: (v) => setSheet(() {
                        if (v) {
                          tempParticipants.add(m.uid);
                        } else {
                          tempParticipants.remove(m.uid);
                        }
                      }),
                      selectedColor: primaryColor,
                      checkmarkColor: Colors.white,
                      backgroundColor: context.colors.background,
                      side: BorderSide(color: context.colors.border),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.calendarRecurrentsUniquement,
                    style: const TextStyle(fontSize: 15),
                  ),
                  Switch(
                    value: tempRecurrence[0],
                    activeThumbColor: primaryColor,
                    onChanged: (v) => setSheet(() => tempRecurrence[0] = v),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: primaryColor),
                  onPressed: () {
                    setState(() {
                      _filterParticipantIds = List<String>.from(
                        tempParticipants,
                      );
                      _filterRecurrenceOnly = tempRecurrence[0];
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(context.l10n.calendarAppliquer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Event> _applyFilters(List<Event> events, String search) => EventFilter(
    search: search,
    participantIds: _filterParticipantIds.toSet(),
    recurrenceOnly: _filterRecurrenceOnly,
  ).apply(events);
}
