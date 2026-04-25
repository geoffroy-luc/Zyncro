import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/reminder_service.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/recurrence_rule.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/providers/messages_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../providers/events_provider.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final Event? event;

  const EventFormScreen({super.key, this.initialDate, this.event});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
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

  static const _colorPalette = [
    '#4F7CFF',
    '#2BB8A5',
    '#FF6B6B',
    '#FFA940',
    '#7B61FF',
    '#52C41A',
    '#FF85C2',
    '#1890FF',
  ];

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
        _endTime = TimeOfDay(hour: _startTime.hour + 1, minute: _startTime.minute);
      }
      _loadReminder(e.id);
      _recurrence = e.recurrence;
      _selectedParticipantIds = e.participantIds.toSet();
    } else {
      _startDate = widget.initialDate ?? DateTime.now();
      _endDate = _startDate;
      _endTime = TimeOfDay(hour: _startTime.hour + 1, minute: _startTime.minute);
    }
  }

  Future<void> _loadReminder(String eventId) async {
    final minutes = await ReminderService.getReminderMinutes(eventId);
    if (mounted) setState(() => _reminderMinutes = minutes);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

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

  DateTime _combine(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

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
            child: const Text('Supprimer',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final user = ref.read(authStateProvider).asData?.value;
      final groupId = ref.read(selectedGroupIdProvider).asData?.value;
      if (groupId == null) return;
      try {
        await ref.read(eventsRepositoryProvider).deleteEvent(groupId, widget.event!.id);
        await ReminderService.cancelReminder(widget.event!.id);
        final userName = user?.displayName ?? user?.email ?? 'Quelqu\'un';
        if (user != null) {
          ref.read(messagesRepositoryProvider).sendSystemMessage(
            groupId: groupId,
            userId: user.uid,
            content: '📅 $userName a supprimé un événement « ${widget.event!.title} »',
            notifScreen: 'calendar',
          );
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission refusée')),
          );
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
    final endDt =
        _hasEndDate && _endDate != null && _endTime != null
            ? _combine(_endDate!, _endTime!)
            : null;

    if (endDt != null && endDt.isBefore(startDt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La date de fin doit être après la date de début')),
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
      final userName = ref.read(currentMemberProvider).asData?.value?.displayName ??
          user.displayName ??
          user.email ??
          'Quelqu\'un';
      final action = isCreating ? 'a créé un événement' : 'a modifié l\'événement';
      ref.read(messagesRepositoryProvider).sendSystemMessage(
        groupId: groupId,
        userId: user.uid,
        content: '📅 $userName $action « $title »',
        notifScreen: 'calendar',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Récurrence ────────────────────────────────────────────────────────────

  Future<void> _showRecurrencePicker() async {
    RecurrenceFrequency? selectedFreq = _recurrence?.frequency;
    RecurrenceEndType endType = _recurrence?.endType ?? RecurrenceEndType.forever;
    int countValue = _recurrence?.count ?? 4;
    final countController = TextEditingController(text: '$countValue');
    DateTime untilDate = _recurrence?.until ?? _startDate.add(const Duration(days: 30));
    final untilController = TextEditingController(
      text: DateFormat('d/M/yyyy').format(untilDate),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final frequencies = [
            (RecurrenceFrequency.daily, 'Tous les jours'),
            (RecurrenceFrequency.weekly, 'Toutes les semaines'),
            (RecurrenceFrequency.monthly, 'Tous les mois'),
            (RecurrenceFrequency.yearly, 'Tous les ans'),
          ];

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Text(
                      'Répétition',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  // Aucune
                  ListTile(
                    leading: Icon(
                      Icons.block_outlined,
                      color: selectedFreq == null
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    title: const Text('Aucune'),
                    trailing: selectedFreq == null
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      setSt(() => selectedFreq = null);
                    },
                  ),
                  // Fréquences
                  ...frequencies.map((f) {
                    final (freq, label) = f;
                    final isSelected = selectedFreq == freq;
                    return ListTile(
                      leading: Icon(
                        Icons.repeat,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      title: Text(label),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () => setSt(() => selectedFreq = freq),
                    );
                  }),

                  // Fin de récurrence (visible seulement si fréquence choisie)
                  if (selectedFreq != null) ...[
                    const Divider(height: 24),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: Text(
                        'Fin de la répétition',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Toujours
                    RadioListTile<RecurrenceEndType>(
                      value: RecurrenceEndType.forever,
                      groupValue: endType,
                      onChanged: (v) => setSt(() => endType = v!),
                      title: const Text('Toujours'),
                      activeColor: AppColors.primary,
                    ),
                    // Nombre de fois
                    RadioListTile<RecurrenceEndType>(
                      value: RecurrenceEndType.count,
                      groupValue: endType,
                      onChanged: (v) => setSt(() => endType = v!),
                      activeColor: AppColors.primary,
                      title: endType == RecurrenceEndType.count
                          ? Row(
                              children: [
                                const Text('Nombre de fois :'),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 72,
                                  child: TextField(
                                    controller: countController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    maxLength: 3,
                                    decoration: const InputDecoration(
                                      counterText: '',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onChanged: (v) {
                                      final n = int.tryParse(v);
                                      if (n != null && n >= 1 && n <= 999) {
                                        setSt(() => countValue = n);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            )
                          : const Text('Nombre de fois'),
                    ),
                    // Jusqu'au
                    RadioListTile<RecurrenceEndType>(
                      value: RecurrenceEndType.until,
                      groupValue: endType,
                      onChanged: (v) => setSt(() => endType = v!),
                      activeColor: AppColors.primary,
                      title: endType == RecurrenceEndType.until
                          ? Row(
                              children: [
                                const Text('Jusqu\'au :'),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: ctx,
                                      initialDate: untilDate,
                                      firstDate: _startDate,
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setSt(() {
                                        untilDate = picked;
                                        untilController.text =
                                            DateFormat('d/M/yyyy').format(picked);
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      DateFormat('d MMM yyyy', 'fr_FR')
                                          .format(untilDate),
                                      style: const TextStyle(
                                          color: AppColors.primary, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Text('Jusqu\'au'),
                    ),
                  ],

                  // Bouton confirmer
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            if (selectedFreq == null) {
                              _recurrence = null;
                            } else {
                              _recurrence = RecurrenceRule(
                                frequency: selectedFreq!,
                                endType: endType,
                                count: endType == RecurrenceEndType.count
                                    ? countValue
                                    : null,
                                until: endType == RecurrenceEndType.until
                                    ? untilDate
                                    : null,
                              );
                            }
                          });
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text('Confirmer'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecurrenceRow() {
    final label = _recurrence?.label ?? 'Aucune répétition';
    return GestureDetector(
      onTap: _showRecurrencePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.repeat, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _recurrence != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

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

  Future<void> _showReminderPicker() async {
    final presets = [
      (null, 'Aucun rappel', Icons.notifications_off_outlined),
      (0, 'Au moment de l\'événement', Icons.notifications_outlined),
      (10, '10 minutes avant', Icons.schedule_outlined),
      (60, '1 heure avant', Icons.schedule_outlined),
      (1440, '1 jour avant', Icons.today_outlined),
    ];

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                'Rappel',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            ...presets.map((p) {
              final (minutes, label, icon) = p;
              final selected = _reminderMinutes == minutes;
              return ListTile(
                leading: Icon(icon,
                    color: selected ? AppColors.primary : AppColors.textSecondary),
                title: Text(label),
                trailing: selected
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _reminderMinutes = minutes);
                  Navigator.pop(ctx);
                },
              );
            }),
            ListTile(
              leading: const Icon(Icons.tune_outlined,
                  color: AppColors.textSecondary),
              title: const Text('Personnalisé…'),
              onTap: () {
                Navigator.pop(ctx);
                _showCustomReminderDialog();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _showCustomReminderDialog() async {
    int value = 30;
    String unit = 'min';
    final controller = TextEditingController(text: '30');

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Rappel personnalisé'),
          content: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => value = int.tryParse(v) ?? value,
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: unit,
                items: const [
                  DropdownMenuItem(value: 'min', child: Text('min')),
                  DropdownMenuItem(value: 'h', child: Text('h')),
                  DropdownMenuItem(value: 'j', child: Text('j')),
                ],
                onChanged: (v) {
                  if (v != null) setSt(() => unit = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                final n = int.tryParse(controller.text) ?? 0;
                final minutes = switch (unit) {
                  'h' => n * 60,
                  'j' => n * 1440,
                  _ => n,
                };
                Navigator.pop(ctx, minutes);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result > 0) {
      setState(() => _reminderMinutes = result);
    }
  }

  Widget _buildReminderRow() {
    return GestureDetector(
      onTap: _showReminderPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_outlined,
                size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _reminderLabel,
                style: TextStyle(
                  color: _reminderMinutes != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
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
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _pickDate(isStart: isStart),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('d MMM yyyy', 'fr_FR').format(date),
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 13),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      time.format(context),
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13),
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

  @override
  Widget build(BuildContext context) {
    ref.watch(currentMemberProvider); // garde le provider actif pour ref.read() dans les méthodes async
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.event != null ? 'Modifier l\'événement' : 'Nouvel événement'),
        actions: [
          if (widget.event != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
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
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  prefixIcon: Icon(Icons.event_outlined),
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
                decoration: const InputDecoration(
                  labelText: 'Lieu (optionnel)',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Text('Couleur',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Row(
                children: _colorPalette.map((hex) {
                  final color = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                  final isSelected = _selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedColor = isSelected ? null : hex;
                    }),
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: AppColors.textPrimary, width: 2.5)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              _dateTimeRow(
                label: 'Début',
                date: _startDate,
                time: _startTime,
                isStart: true,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _hasEndDate,
                onChanged: (v) => setState(() => _hasEndDate = v),
                title: const Text('Ajouter une heure de fin'),
                contentPadding: EdgeInsets.zero,
              ),
              if (_hasEndDate) ...[
                const SizedBox(height: 8),
                _dateTimeRow(
                  label: 'Fin',
                  date: _endDate ?? _startDate,
                  time: _endTime ?? _startTime,
                  isStart: false,
                ),
              ],
              const SizedBox(height: 24),
              // Participants
              Builder(builder: (context) {
                final members = ref.watch(groupMembersProvider).asData?.value ?? [];
                final currentUid = ref.watch(authStateProvider).asData?.value?.uid;
                if (members.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Participants',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: members.map((m) {
                        final isSelected = _selectedParticipantIds.contains(m.uid);
                        final color = avatarColorForUid(m.uid);
                        final label = m.uid == currentUid ? 'Vous' : m.displayName;
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withValues(alpha: 0.10) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? color : AppColors.border,
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
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected ? color : AppColors.textPrimary,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.check_circle_rounded, size: 14, color: color),
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
              }),
              Text(
                'Répétition',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildRecurrenceRow(),
              const SizedBox(height: 24),
              Text(
                'Rappel',
                style: const TextStyle(
                  color: AppColors.textSecondary,
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
