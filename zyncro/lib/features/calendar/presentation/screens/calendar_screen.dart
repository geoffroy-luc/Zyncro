import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/event.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/providers/messages_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../providers/events_provider.dart';
import 'event_form_screen.dart';

const _defaultEventColor = Color(0xFF4F7CFF);

Color _eventColor(Event e) {
  if (e.color == null) return _defaultEventColor;
  try {
    return Color(int.parse('FF${e.color!.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return _defaultEventColor;
  }
}

String _timeLabel(DateTime dt) => DateFormat('HH:mm').format(dt);

enum _ViewMode { month, agenda }

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _ViewMode _viewMode = _ViewMode.month;
  DateTime _displayedMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  void _prevMonth() => setState(() {
        _displayedMonth =
            DateTime(_displayedMonth.year, _displayedMonth.month - 1);
        _selectedDay = null;
      });

  void _nextMonth() => setState(() {
        _displayedMonth =
            DateTime(_displayedMonth.year, _displayedMonth.month + 1);
        _selectedDay = null;
      });

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _eventOnDay(Event e, DateTime day) =>
      _isSameDay(e.startDate, day) ||
      (e.endDate != null &&
          !e.startDate.isAfter(day) &&
          !e.endDate!.isBefore(day));

  List<Event> _eventsForMonth(List<Event> events) => events.where((e) {
        return e.startDate.year == _displayedMonth.year &&
            e.startDate.month == _displayedMonth.month;
      }).toList();

  List<Widget> _buildAgendaSections(List<Event> events) {
    final Map<DateTime, List<Event>> grouped = {};
    for (final e in events) {
      final day =
          DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
      grouped.putIfAbsent(day, () => []).add(e);
    }
    final sortedDays = grouped.keys.toList()..sort();
    final today = DateTime.now();
    final widgets = <Widget>[];

    for (final day in sortedDays) {
      final isToday = _isSameDay(day, today);
      final isTomorrow = _isSameDay(
          day, DateTime(today.year, today.month, today.day + 1));

      final label = isToday
          ? "Aujourd'hui"
          : isTomorrow
              ? 'Demain'
              : DateFormat('EEEE d MMMM', 'fr_FR').format(day);

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: isToday
                    ? const LinearGradient(
                        colors: [Color(0xFF4F7CFF), Color(0xFF315FEA)])
                    : null,
                color: isToday
                    ? null
                    : isTomorrow
                        ? const Color(0x1A2BB8A5)
                        : const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isToday
                      ? Colors.white
                      : isTomorrow
                          ? AppColors.secondary
                          : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...grouped[day]!.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AgendaEventCard(event: e),
                )),
          ],
        ),
      ));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final eventsAsync = ref.watch(eventsProvider);
    final allEvents = eventsAsync.asData?.value ?? [];
    final monthEvents = _eventsForMonth(allEvents);
    final today = DateTime.now();

    final visibleEvents = _selectedDay != null
        ? allEvents.where((e) => _eventOnDay(e, _selectedDay!)).toList()
        : monthEvents;

    final firstOfMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventFormScreen(initialDate: _selectedDay ?? today),
          ),
        ),
        backgroundColor: const Color(0xFF4F7CFF).withValues(alpha: 0.85),
        shape: const CircleBorder(side: BorderSide(color: Colors.white24, width: 2)),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Calendrier',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                            color: const Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.chevron_left,
                              size: 20, color: AppColors.textSecondary),
                        ),
                      ),
                      Text(
                        DateFormat('MMMM yyyy', 'fr_FR').format(_displayedMonth),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
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
                            color: const Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.chevron_right,
                              size: 20, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Toggle vue
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _ToggleButton(
                          label: 'Mois',
                          active: _viewMode == _ViewMode.month,
                          onTap: () =>
                              setState(() => _viewMode = _ViewMode.month),
                        ),
                        _ToggleButton(
                          label: 'Agenda',
                          active: _viewMode == _ViewMode.agenda,
                          onTap: () =>
                              setState(() => _viewMode = _ViewMode.agenda),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Divider(height: 1, color: AppColors.border),
          ),

          // ── Corps ────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_viewMode == _ViewMode.month) ...[
                  // Grille
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam']
                              .map((d) => Expanded(
                                    child: Center(
                                      child: Text(d,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          )),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 1,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                          itemCount: leadingBlanks + daysInMonth,
                          itemBuilder: (_, i) {
                            if (i < leadingBlanks) return const SizedBox();
                            final dayNum = i - leadingBlanks + 1;
                            final cellDate = DateTime(_displayedMonth.year,
                                _displayedMonth.month, dayNum);
                            final isToday = _isSameDay(cellDate, today);
                            final isSelected = _selectedDay != null &&
                                _isSameDay(cellDate, _selectedDay!);
                            final dayEvents = monthEvents
                                .where((e) => _eventOnDay(e, cellDate))
                                .toList();
                            return GestureDetector(
                              onTap: () => setState(() {
                                _selectedDay =
                                    isSelected ? null : cellDate;
                              }),
                              child: Container(
                                decoration: isSelected
                                    ? BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                            color: AppColors.primary,
                                            width: 1.5),
                                      )
                                    : isToday
                                        ? BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFF4F7CFF),
                                                Color(0xFF315FEA)
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            boxShadow: const [
                                              BoxShadow(
                                                  color: Color(0x334F7CFF),
                                                  blurRadius: 6,
                                                  offset: Offset(0, 2))
                                            ],
                                          )
                                        : null,
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$dayNum',
                                      style: TextStyle(
                                        color: isToday
                                            ? Colors.white
                                            : isSelected
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (dayEvents.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: dayEvents.take(3).map((e) =>
                                            Container(
                                              width: 4,
                                              height: 4,
                                              margin: const EdgeInsets.symmetric(horizontal: 1),
                                              decoration: BoxDecoration(
                                                color: isToday
                                                    ? Colors.white
                                                    : _eventColor(e),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ).toList(),
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
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Text(
                    DateFormat('MMMM yyyy', 'fr_FR').format(_displayedMonth),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
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
                          const Icon(Icons.event_outlined,
                              size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          const Text('Aucun événement',
                              style:
                                  TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EventFormScreen(
                                    initialDate: _selectedDay ?? today),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter un événement'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_viewMode == _ViewMode.agenda)
                  ..._buildAgendaSections(visibleEvents)
                else
                  ...visibleEvents.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _EventCard(event: e),
                      )),

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleButton(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? const [
                    BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 4,
                        offset: Offset(0, 1))
                  ]
                : null,
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  color:
                      active ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                )),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  final Event event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _eventColor(event);
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    final authUser = ref.watch(authStateProvider).asData?.value;
    final group = ref.watch(selectedGroupProvider);

    // Peut supprimer : créateur de l'event OU owner du groupe
    final canDelete = authUser != null && (
      event.createdBy == authUser.uid ||
      group?.createdBy == authUser.uid
    );

    void openEdit() {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EventFormScreen(event: event),
      ));
    }

    final cardContent = GestureDetector(
      onTap: canDelete ? openEdit : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.access_time,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      event.endDate != null
                          ? '${_timeLabel(event.startDate)} → ${_timeLabel(event.endDate!)}'
                          : _timeLabel(event.startDate),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ]),
                  if (event.location != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.place_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(event.location!,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                  if (event.creatorName != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.person_outline,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(event.creatorName!,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ]),
                  ],
                ],
              ),
            ),
            if (canDelete)
              const Icon(Icons.edit_outlined,
                  size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );

    if (!canDelete) return cardContent;

    return Dismissible(
      key: Key(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Supprimer l\'événement'),
          content: const Text('Cette action est irréversible.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
      onDismissed: (_) async {
        if (groupId != null) {
          final authUserSnap = ref.read(authStateProvider).asData?.value;
          final eventsRepo = ref.read(eventsRepositoryProvider);
          final msgRepo = ref.read(messagesRepositoryProvider);
          try {
            await eventsRepo.deleteEvent(groupId, event.id);
            final userName = authUserSnap?.displayName ?? authUserSnap?.email ?? 'Quelqu\'un';
            if (authUserSnap != null) {
              msgRepo.sendSystemMessage(
                groupId: groupId,
                userId: authUserSnap.uid,
                content: '📅 $userName a supprimé un événement « ${event.title} »',
                notifScreen: 'calendar',
              );
            }
          } catch (_) {}
        }
      },
      child: cardContent,
    );
  }
}

class _AgendaEventCard extends ConsumerWidget {
  final Event event;
  const _AgendaEventCard({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _eventColor(event);
    final authUser = ref.watch(authStateProvider).asData?.value;
    final group = ref.watch(selectedGroupProvider);

    final canEdit = authUser != null && (
      event.createdBy == authUser.uid ||
      group?.createdBy == authUser.uid
    );

    return GestureDetector(
      onTap: canEdit
          ? () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => EventFormScreen(event: event),
              ))
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(event.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                ),
                if (canEdit)
                  const Icon(Icons.edit_outlined,
                      size: 16, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.access_time,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                event.endDate != null
                    ? '${_timeLabel(event.startDate)} → ${_timeLabel(event.endDate!)}'
                    : _timeLabel(event.startDate),
                style:
                    const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              if (event.location != null) ...[
                const SizedBox(width: 16),
                const Icon(Icons.place_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(event.location!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ]),
            if (event.creatorName != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(event.creatorName!,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
