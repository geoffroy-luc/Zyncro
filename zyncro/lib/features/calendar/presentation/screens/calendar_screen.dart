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
import 'package:zyncro/features/calendar/presentation/widgets/month_swipe_detector.dart';
import 'package:zyncro/features/calendar/presentation/widgets/view_mode.dart';
import 'package:zyncro/features/groups/domain/entities/group_member.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';

part 'calendar_screen_agenda.dart';
part 'calendar_screen_filters.dart';
part 'calendar_screen_sections.dart';

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

  /// Sens du dernier changement de mois (+1 suivant, -1 précédent) : sens
  /// de l'animation de la grille.
  int _monthStep = 1;
  DateTime? _selectedDay;

  // Filtres locaux
  List<String> _filterParticipantIds = [];
  bool _filterRecurrenceOnly = false;

  bool get _hasActiveFilters =>
      _filterParticipantIds.isNotEmpty || _filterRecurrenceOnly;

  // ── Implémentées par les mixins ──
}

class _CalendarScreenState extends _CalendarScreenStateBase
    with _CalendarFilterActions, _CalendarNavigation, _CalendarScreenSections {
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
    final monthEvents = eventsInMonth(allEvents, _displayedMonth);
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
            _buildHeader(primaryColor, members),
            SliverToBoxAdapter(
              child: Divider(height: 1, color: context.colors.border),
            ),

            // ── Corps ────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_viewMode == ViewMode.month) ...[
                    // Grille : balayer à gauche / à droite change de mois.
                    MonthSwipeDetector(
                      onPrevious: _prevMonth,
                      onNext: _nextMonth,
                      child: MonthSlideSwitcher(
                        month: _displayedMonth,
                        step: _monthStep,
                        child: _buildMonthGrid(
                          displayMode,
                          primaryColor,
                          monthEvents,
                          today,
                          daysInMonth,
                          leadingBlanks,
                        ),
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
                    _buildEmptyEvents(primaryColor, today)
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
