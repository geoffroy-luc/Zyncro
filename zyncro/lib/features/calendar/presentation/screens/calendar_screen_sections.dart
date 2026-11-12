part of 'calendar_screen.dart';

/// Sections du build (en-tête, grille du mois, état vide) : déplacement pur.
mixin _CalendarScreenSections
    on _CalendarScreenStateBase, _CalendarFilterActions, _CalendarNavigation {
  Widget _buildHeader(Color primaryColor, List<GroupMember> members) {
    return SliverToBoxAdapter(
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
                  DateFormat('MMMM yyyy', 'fr_FR').format(_displayedMonth),
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
                        hintText: context.l10n.calendarRechercher,
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
                    onTap: () => _showFilterSheet(members, primaryColor),
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
                    label: context.l10n.calendarMois,
                    active: _viewMode == ViewMode.month,
                    onTap: () => setState(() => _viewMode = ViewMode.month),
                  ),
                  CalendarToggleButton(
                    label: context.l10n.calendarAgenda,
                    active: _viewMode == ViewMode.agenda,
                    onTap: () => setState(() => _viewMode = ViewMode.agenda),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGrid(
    String displayMode,
    Color primaryColor,
    List<Event> monthEvents,
    DateTime today,
    int daysInMonth,
    int leadingBlanks,
  ) {
    return Container(
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
            children: ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          color: context.colors.textSecondary,
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                  _selectedDay != null && isSameDay(cellDate, _selectedDay!);
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
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: primaryColor, width: 1.5),
                        )
                      : isToday
                      ? BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [primaryColor, darken(primaryColor)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.2),
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
                          padding: const EdgeInsets.only(top: 2),
                          child: displayMode == 'band'
                              ? Column(
                                  children: dayEvents
                                      .take(2)
                                      .map(
                                        (e) => Container(
                                          height: 3,
                                          margin: const EdgeInsets.only(
                                            bottom: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isToday
                                                ? Colors.white.withValues(
                                                    alpha: 0.8,
                                                  )
                                                : calendarEventColor(e),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: dayEvents
                                      .take(3)
                                      .map(
                                        (e) => Container(
                                          width: 4,
                                          height: 4,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isToday
                                                ? Colors.white
                                                : calendarEventColor(e),
                                            shape: BoxShape.circle,
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
    );
  }

  Widget _buildEmptyEvents(Color primaryColor, DateTime today) {
    return Center(
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
              context.l10n.calendarAucunEvenement,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      EventFormScreen(initialDate: _selectedDay ?? today),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.calendarAjouterUnEvenement),
            ),
          ],
        ),
      ),
    );
  }
}
