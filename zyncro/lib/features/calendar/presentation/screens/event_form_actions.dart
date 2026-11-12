part of 'event_form_screen.dart';

/// Dates / heures, enregistrement, suppression, couleurs personnalisées.
mixin _EventFormActions on _EventFormScreenStateBase {
  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer l\'événement'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Supprimer',
              style: TextStyle(color: context.colors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final user = ref.read(authStateProvider).asData?.value;
      final groupId = ref.read(selectedGroupIdProvider).asData?.value;
      if (groupId == null) return;
      try {
        await ref
            .read(eventsRepositoryProvider)
            .deleteEvent(groupId, widget.event!.id);
        await ReminderService.cancelReminder(widget.event!.id);
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Permission refusée')));
        }
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
        const SnackBar(
          content: Text('La date de fin doit être après la date de début'),
        ),
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
        final updated = widget.event!.copyWith(
          title: title,
          description: description,
          startDate: startDt,
          endDate: endDt,
          location: location,
          color: _selectedColor,
          updatedBy: user.uid,
          recurrence: _recurrence,
          clearRecurrence: _recurrence == null,
          participantIds: _selectedParticipantIds.toList(),
        );
        await repo.updateEvent(groupId, updated);
        await ReminderService.scheduleReminder(updated, _reminderMinutes);
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
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
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
