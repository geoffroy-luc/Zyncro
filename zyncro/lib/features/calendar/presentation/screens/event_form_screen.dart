import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zyncro/core/constants/app_colors.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/calendar/data/services/reminder_service.dart';
import 'package:zyncro/features/calendar/domain/entities/event.dart';
import 'package:zyncro/features/calendar/presentation/providers/events_provider.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';
import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';
import 'package:zyncro/shared/presentation/recurrence_rule_label.dart';
import 'package:zyncro/shared/widgets/color_picker_row.dart';
import 'package:zyncro/shared/widgets/user_avatar.dart';

part 'event_form_recurrence.dart';
part 'event_form_reminder.dart';
part 'event_form_actions.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final Event? event;

  const EventFormScreen({super.key, this.initialDate, this.event});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

/// Champs et contrat commun des mixins de l'écran (parts event_form_recurrence.dart, event_form_reminder.dart, event_form_actions.dart).
abstract class _EventFormScreenStateBase
    extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  late DateTime _startDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  bool _hasEndDate = false;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _saving = false;
  String? _selectedColor;
  int? _reminderMinutes; // null = aucun rappel
  RecurrenceRule? _recurrence;
  Set<String> _selectedParticipantIds = {};

  DateTime _combine(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  // ── Rappel ────────────────────────────────────────────────────────────────

  String get _reminderLabel {
    if (_reminderMinutes == null) return 'Aucun rappel';
    if (_reminderMinutes == 0) return 'Au moment de l\'événement';
    if (_reminderMinutes == 10) return '10 minutes avant';
    if (_reminderMinutes == 60) return '1 heure avant';
    if (_reminderMinutes == 1440) return '1 jour avant';
    final m = _reminderMinutes!;
    if (m < 60) return '$m minutes avant';
    if (m < 1440) return '${m ~/ 60} heures avant';
    return '${m ~/ 1440} jours avant';
  }

  // ── Implémentées par les mixins ──
}

class _EventFormScreenState extends _EventFormScreenStateBase
    with _EventFormRecurrence, _EventFormReminder, _EventFormActions {
  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _titleController.text = e.title;
      _locationController.text = e.location ?? '';
      _descriptionController.text = e.description ?? '';
      _startDate = e.startDate;
      _startTime = TimeOfDay.fromDateTime(e.startDate);
      _selectedColor = e.color;
      if (e.endDate != null) {
        _hasEndDate = true;
        _endDate = e.endDate;
        _endTime = TimeOfDay.fromDateTime(e.endDate!);
      } else {
        _endDate = _startDate;
        _endTime = TimeOfDay(
          hour: _startTime.hour + 1,
          minute: _startTime.minute,
        );
      }
      unawaited(_loadReminder(e.id));
      _recurrence = e.recurrence;
      _selectedParticipantIds = e.participantIds.toSet();
    } else {
      _startDate = widget.initialDate ?? DateTime.now();
      _endDate = _startDate;
      _endTime = TimeOfDay(
        hour: _startTime.hour + 1,
        minute: _startTime.minute,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      currentMemberProvider,
    ); // garde le provider actif pour ref.read() dans les méthodes async
    final tabSettings =
        ref.watch(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          widget.event != null ? 'Modifier l\'événement' : 'Nouvel événement',
        ),
        actions: [
          if (widget.event != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: context.colors.error),
              onPressed: _delete,
            ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: context.l10n.calendarTitre,
                  prefixIcon: const Icon(Icons.event_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 50,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                  if (v.trim().length > 50) return '50 caractères maximum';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: context.l10n.calendarLieuOptionnel,
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: context.l10n.calendarDescriptionOptionnel,
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.calendarCouleur,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              ColorPickerRow(
                basePalette: AppColors.itemPalette,
                selected: _selectedColor,
                extraColors: tabSettings.customColors,
                hiddenBaseColors: tabSettings.hiddenBaseColors,
                onSelect: (hex) => setState(() => _selectedColor = hex),
                onAddColor: _addCustomColor,
                onDeleteColor: _deleteCustomColor,
              ),
              const SizedBox(height: 24),
              _dateTimeRow(
                label: context.l10n.calendarDebut,
                date: _startDate,
                time: _startTime,
                isStart: true,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _hasEndDate,
                onChanged: (v) => setState(() => _hasEndDate = v),
                title: Text(context.l10n.calendarAjouterUneHeureDeFin),
                contentPadding: EdgeInsets.zero,
              ),
              if (_hasEndDate) ...[
                const SizedBox(height: 8),
                _dateTimeRow(
                  label: context.l10n.calendarFin,
                  date: _endDate ?? _startDate,
                  time: _endTime ?? _startTime,
                  isStart: false,
                ),
              ],
              const SizedBox(height: 24),
              // Participants
              Builder(
                builder: (context) {
                  final members =
                      ref.watch(groupMembersProvider).asData?.value ?? [];
                  final currentUid = ref
                      .watch(authStateProvider)
                      .asData
                      ?.value
                      ?.uid;
                  if (members.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.calendarParticipants,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: members.map((m) {
                          final isSelected = _selectedParticipantIds.contains(
                            m.uid,
                          );
                          final color = avatarColorForUid(m.uid);
                          final label = m.uid == currentUid
                              ? 'Vous'
                              : m.displayName;
                          return GestureDetector(
                            onTap: () => setState(() {
                              if (isSelected) {
                                _selectedParticipantIds.remove(m.uid);
                              } else {
                                _selectedParticipantIds.add(m.uid);
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withValues(alpha: 0.10)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : context.colors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  UserAvatar(
                                    photoUrl: m.photoUrl,
                                    showPhoto: m.showProfilePhoto,
                                    displayName: m.displayName,
                                    radius: 14,
                                    color: color,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? color
                                          : context.colors.textPrimary,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: color,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
              Text(
                context.l10n.calendarRepetition,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildRecurrenceRow(),
              const SizedBox(height: 24),
              Text(
                context.l10n.calendarRappel,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildReminderRow(),
            ],
          ),
        ),
      ),
    );
  }
}
