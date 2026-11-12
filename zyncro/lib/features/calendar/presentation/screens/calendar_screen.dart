import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/calendar/domain/entities/event.dart';
import 'package:zyncro/features/calendar/domain/services/calendar_queries.dart';
import 'package:zyncro/features/calendar/domain/services/event_filter.dart';
import 'package:zyncro/features/calendar/presentation/providers/events_provider.dart';
import 'package:zyncro/features/calendar/presentation/screens/event_form_screen.dart';
import 'package:zyncro/features/calendar/presentation/widgets/agenda_event_card.dart';
import 'package:zyncro/features/calendar/presentation/widgets/calendar_event_card.dart';
import 'package:zyncro/features/calendar/presentation/widgets/calendar_screen_helpers.dart';
import 'package:zyncro/features/calendar/presentation/widgets/calendar_toggle_button.dart';
import 'package:zyncro/features/calendar/presentation/widgets/view_mode.dart';
import 'package:zyncro/features/groups/domain/entities/group_member.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';

part 'calendar_screen_filters.dart';
part 'calendar_screen_agenda.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

/// Champs et contrat commun des mixins de l'écran (parts calendar_screen_filters.dart, calendar_screen_agenda.dart).
abstract class _CalendarScreenStateBase extends ConsumerState<CalendarScreen> {
  ViewMode _viewMode = ViewMode.month;
  String _search = '';
  DateTime _displayedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  DateTime? _selectedDay;

  // Filtres locaux
  List<String> _filterParticipantIds = [];
  bool _filterRecurrenceOnly = false;

  bool get _hasActiveFilters =>
      _filterParticipantIds.isNotEmpty || _filterRecurrenceOnly;

  // ── Implémentées par les mixins ──
}

class _CalendarScreenState extends _CalendarScreenStateBase
    with _CalendarFilterActions, _CalendarNavigation {
  @override
  Widget build(BuildContext context) {
    final tabSettings =
        ref.watch(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    final displayMode = tabSettings.calendarDisplayMode;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final members = ref.watch(groupMembersProvider).asData?.value ?? [];

    final eventsAsync = ref.watch(expandedEventsProvider);
    final rawEvents = eventsAsync.asData?.value ?? [];
    final allEvents = _applyFilters(rawEvents, _search);
    final monthEvents = eventsStartingInMonth(allEvents, _displayedMonth);
    final today = DateTime.now();

    final visibleEvents = _selectedDay != null
        ? allEvents.where((e) => eventOccursOnDay(e, _selectedDay!)).toList()
        : monthEvents;

    final firstOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month);
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final leadingBlanks = firstOfMonth.weekday - 1;

    return Scaffold(
      backgroundColor: context.colors.background,
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_calendar',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EventFormScreen(initialDate: _selectedDay ?? today),
          ),
        ),
        backgroundColor: primaryColor.withValues(alpha: 0.85),
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white24, width: 2),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  children: [
                    // Navigation mois
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _prevMonth,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: context.colors.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.chevron_left,
                              size: 20,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat(
                            'MMMM yyyy',
                            'fr_FR',
                          ).format(_displayedMonth),
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: _nextMonth,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: context.colors.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: context.colors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Icon(
                              Icons.search,
                              color: context.colors.textSecondary,
                              size: 20,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(() => _search = v),
                              decoration: InputDecoration(
                                hintText: 'Rechercher...',
                                hintStyle: TextStyle(
                                  color: context.colors.textSecondary,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                filled: false,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () =>
                                _showFilterSheet(members, primaryColor),
                            child: Container(
                              width: 36,
                              height: 36,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: _hasActiveFilters
                                    ? primaryColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                size: 18,
                                color: _hasActiveFilters
                                    ? Colors.white
                                    : context.colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Toggle vue
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.colors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CalendarToggleButton(
                            label: 'Mois',
                            active: _viewMode == ViewMode.month,
                            onTap: () =>
                                setState(() => _viewMode = ViewMode.month),
                          ),
                          CalendarToggleButton(
                            label: 'Agenda',
                            active: _viewMode == ViewMode.agenda,
                            onTap: () =>
                                setState(() => _viewMode = ViewMode.agenda),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Divider(height: 1, color: context.colors.border),
            ),

            // ── Corps ────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_viewMode == ViewMode.month) ...[
                    // Grille
                    Container(
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
                      child: Column(
                        children: [
                          Row(
                            children:
                                [
                                      'Lun',
                                      'Mar',
                                      'Mer',
                                      'Jeu',
                                      'Ven',
                                      'Sam',
                                      'Dim',
                                    ]
                                    .map(
                                      (d) => Expanded(
                                        child: Center(
                                          child: Text(
                                            d,
                                            style: TextStyle(
                                              color:
                                                  context.colors.textSecondary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                          const SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  mainAxisSpacing: 4,
                                  crossAxisSpacing: 4,
                                ),
                            itemCount: leadingBlanks + daysInMonth,
                            itemBuilder: (_, i) {
                              if (i < leadingBlanks) return const SizedBox();
                              final dayNum = i - leadingBlanks + 1;
                              final cellDate = DateTime(
                                _displayedMonth.year,
                                _displayedMonth.month,
                                dayNum,
                              );
                              final isToday = isSameDay(cellDate, today);
                              final isSelected =
                                  _selectedDay != null &&
                                  isSameDay(cellDate, _selectedDay!);
                              final dayEvents = monthEvents
                                  .where((e) => eventOccursOnDay(e, cellDate))
                                  .toList();
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() {
                                  _selectedDay = cellDate;
                                }),
                                child: Container(
                                  decoration: isSelected
                                      ? BoxDecoration(
                                          color: primaryColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: primaryColor,
                                            width: 1.5,
                                          ),
                                        )
                                      : isToday
                                      ? BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              primaryColor,
                                              darken(primaryColor),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryColor.withValues(
                                                alpha: 0.2,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        )
                                      : null,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$dayNum',
                                        style: TextStyle(
                                          color: isToday
                                              ? Colors.white
                                              : isSelected
                                              ? primaryColor
                                              : context.colors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (dayEvents.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: displayMode == 'band'
                                              ? Column(
                                                  children: dayEvents
                                                      .take(2)
                                                      .map(
                                                        (e) => Container(
                                                          height: 3,
                                                          margin:
                                                              const EdgeInsets.only(
                                                                bottom: 1,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: isToday
                                                                ? Colors.white
                                                                      .withValues(
                                                                        alpha:
                                                                            0.8,
                                                                      )
                                                                : calendarEventColor(
                                                                    e,
                                                                  ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  2,
                                                                ),
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: dayEvents
                                                      .take(3)
                                                      .map(
                                                        (e) => Container(
                                                          width: 4,
                                                          height: 4,
                                                          margin:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 1,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: isToday
                                                                ? Colors.white
                                                                : calendarEventColor(
                                                                    e,
                                                                  ),
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                                ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _selectedDay != null
                          ? DateFormat('d MMMM', 'fr_FR').format(_selectedDay!)
                          : 'Événements du mois',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text(
                      DateFormat('MMMM yyyy', 'fr_FR').format(_displayedMonth),
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Events
                  if (eventsAsync.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (visibleEvents.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_outlined,
                              size: 48,
                              color: context.colors.textSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Aucun événement',
                              style: TextStyle(
                                color: context.colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => EventFormScreen(
                                    initialDate: _selectedDay ?? today,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Ajouter un événement'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_viewMode == ViewMode.agenda)
                    ..._buildAgendaSections(visibleEvents, primaryColor)
                  else
                    ...visibleEvents.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CalendarEventCard(event: e),
                      ),
                    ),

                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
