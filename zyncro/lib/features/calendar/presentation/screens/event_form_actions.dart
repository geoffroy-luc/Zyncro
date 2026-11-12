part of 'event_form_screen.dart';

/// Dates / heures, enregistrement, suppression, couleurs personnalisées.
mixin _EventFormActions on _EventFormScreenStateBase {
  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      // BUG CA4 corrigé : bornes qui contiennent toujours la date initiale
      // (assertion de showDatePicker sinon) et plus de plafond à 2030.
      firstDate: initial.isBefore(DateTime(2020)) ? initial : DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 20).isAfter(initial)
          ? DateTime(DateTime.now().year + 20)
          : initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : (_endTime ?? _startTime);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _delete() async {
    final original = widget.event!;
    // BUG CA6 corrigé : sur une occurrence (hors première), choix entre
    // « celle-ci et les suivantes » et toute la série ; sur la première,
    // l'avertissement dit que la série entière part.
    if (original.isSeriesOccurrence && original.occurrenceIndex! > 0) {
      final scope = await showSeriesScopeDialog(
        context,
        title: context.l10n.calendarSupprimerRecurrent,
        deleting: true,
      );
      if (scope == null || !mounted) return;
      if (scope == SeriesScope.thisAndFollowing) {
        await _guarded(() async {
          await ref
              .read(eventsRepositoryProvider)
              .updateEvent(_groupIdOrThrow(), _truncatedBase(original));
          if (mounted) Navigator.of(context).pop();
        });
        return;
      }
      await _deleteConfirmed(original);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.calendarSupprimerLEvenement),
        content: Text(
          original.recurrence != null
              ? context.l10n.seriesSuppressionSerieEntiere
              : context.l10n.calendarCetteActionEstIrreversible,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.calendarAnnuler),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.l10n.calendarSupprimer,
              style: TextStyle(color: context.colors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) await _deleteConfirmed(original);
  }

  String _groupIdOrThrow() {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) throw StateError('Aucun groupe sélectionné');
    return groupId;
  }

  /// La série d'origine (document de base), arrêtée juste avant [occurrence].
  Event _truncatedBase(Event occurrence) {
    final start = occurrence.seriesStart!;
    final duration = occurrence.endDate?.difference(occurrence.startDate);
    return occurrence.copyWith(
      startDate: start,
      endDate: duration == null ? null : start.add(duration),
      recurrence: truncateBefore(
        occurrence.recurrence!,
        index: occurrence.occurrenceIndex!,
        occurrence: occurrence.startDate,
      ),
    );
  }

  Future<void> _guarded(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.calendarErreur(e))));
      }
    }
  }

  Future<void> _deleteConfirmed(Event original) async {
    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    try {
      await ref
          .read(eventsRepositoryProvider)
          .deleteEvent(groupId, original.id);
      await ReminderService.cancelReminder(original.id);
      final userName = user?.displayName ?? user?.email ?? 'Quelqu\'un';
      if (user != null) {
        unawaited(
          ref
              .read(messagesRepositoryProvider)
              .sendSystemMessage(
                groupId: groupId,
                userId: user.uid,
                content:
                    '📅 $userName a supprimé un événement « ${widget.event!.title} »',
                notifScreen: 'calendar',
              ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        // BUG CA6 (message) corrigé : « Permission refusée » seulement si
        // c'en est une.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              FailureMapper.from(e) is PermissionDeniedFailure
                  ? context.l10n.calendarPermissionRefusee
                  : context.l10n.calendarErreur(e),
            ),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (user == null || groupId == null) return;

    final startDt = _combine(_startDate, _startTime);
    final endDt = _hasEndDate && _endDate != null && _endTime != null
        ? _combine(_endDate!, _endTime!)
        : null;

    if (endDt != null && endDt.isBefore(startDt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.calendarLaDateDeFinDoit)),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(eventsRepositoryProvider);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim().isNotEmpty
        ? _descriptionController.text.trim()
        : null;
    final location = _locationController.text.trim().isNotEmpty
        ? _locationController.text.trim()
        : null;
    try {
      final isCreating = widget.event == null;
      if (!isCreating) {
        final original = widget.event!;
        // BUG K2 (1) corrigé : sur une occurrence (hors première), choix de
        // la portée ; l'ancre de la série n'est plus réécrite à sa date.
        var scope = SeriesScope.wholeSeries;
        if (original.isSeriesOccurrence && original.occurrenceIndex! > 0) {
          final chosen = await showSeriesScopeDialog(
            context,
            title: context.l10n.calendarModifierRecurrent,
            deleting: false,
          );
          if (chosen == null) {
            if (mounted) setState(() => _saving = false);
            return;
          }
          scope = chosen;
        }
        if (scope == SeriesScope.thisAndFollowing) {
          await repo.updateEvent(groupId, _truncatedBase(original));
          final created = await repo.createEvent(
            groupId: groupId,
            title: title,
            description: description,
            startDate: startDt,
            endDate: endDt,
            location: location,
            userId: user.uid,
            color: _selectedColor,
            recurrence: sameRule(_recurrence, original.recurrence)
                ? continueFrom(
                    original.recurrence!,
                    index: original.occurrenceIndex!,
                  )
                : _recurrence,
            participantIds: _selectedParticipantIds.toList(),
            creatorName: ref
                .read(currentMemberProvider)
                .asData
                ?.value
                ?.displayName,
          );
          await ReminderService.scheduleReminder(created, _reminderMinutes);
        } else {
          final anchorStart = original.isSeriesOccurrence
              ? shiftAnchor(
                  original.seriesStart!,
                  occurrence: original.startDate,
                  edited: startDt,
                )
              : startDt;
          final updated = original.copyWith(
            title: title,
            description: description,
            clearDescription: description == null,
            startDate: anchorStart,
            endDate: endDt == null
                ? null
                : anchorStart.add(endDt.difference(startDt)),
            clearEndDate: endDt == null,
            location: location,
            clearLocation: location == null,
            color: _selectedColor,
            clearColor: _selectedColor == null,
            updatedBy: user.uid,
            recurrence: _recurrence,
            clearRecurrence: _recurrence == null,
            participantIds: _selectedParticipantIds.toList(),
          );
          await repo.updateEvent(groupId, updated);
          await ReminderService.scheduleReminder(updated, _reminderMinutes);
        }
      } else {
        final created = await repo.createEvent(
          groupId: groupId,
          title: title,
          description: description,
          startDate: startDt,
          endDate: endDt,
          location: location,
          userId: user.uid,
          color: _selectedColor,
          recurrence: _recurrence,
          participantIds: _selectedParticipantIds.toList(),
          creatorName: ref
              .read(currentMemberProvider)
              .asData
              ?.value
              ?.displayName,
        );
        await ReminderService.scheduleReminder(created, _reminderMinutes);
      }
      final userName =
          ref.read(currentMemberProvider).asData?.value?.displayName ??
          user.displayName ??
          user.email ??
          'Quelqu\'un';
      final action = isCreating
          ? 'a créé un événement'
          : 'a modifié l\'événement';
      unawaited(
        ref
            .read(messagesRepositoryProvider)
            .sendSystemMessage(
              groupId: groupId,
              userId: user.uid,
              content: '📅 $userName $action « $title »',
              notifScreen: 'calendar',
            ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.calendarErreur(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dateTimeRow({
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required bool isStart,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _pickDate(isStart: isStart),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: context.colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('d MMM yyyy', 'fr_FR').format(date),
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _pickTime(isStart: isStart),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: context.colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time.format(context),
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addCustomColor(String hex) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    final settings =
        ref.read(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    await ref
        .read(tabSettingsRepositoryProvider)
        .updateSettings(
          groupId,
          from: settings,
          to: settings.copyWith(customColors: [...settings.customColors, hex]),
        );
  }

  Future<void> _deleteCustomColor(String hex) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    final settings =
        ref.read(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    await ref
        .read(tabSettingsRepositoryProvider)
        .updateSettings(
          groupId,
          from: settings,
          to: settings.withColorRemoved(hex),
        );
  }
}
