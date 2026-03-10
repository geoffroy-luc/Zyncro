import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/event.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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
      if (e.endDate != null) {
        _hasEndDate = true;
        _endDate = e.endDate;
        _endTime = TimeOfDay.fromDateTime(e.endDate!);
      } else {
        _endDate = _startDate;
        _endTime = TimeOfDay(hour: _startTime.hour + 1, minute: _startTime.minute);
      }
    } else {
      _startDate = widget.initialDate ?? DateTime.now();
      _endDate = _startDate;
      _endTime = TimeOfDay(hour: _startTime.hour + 1, minute: _startTime.minute);
    }
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
      if (widget.event != null) {
        await repo.updateEvent(
          groupId,
          widget.event!.copyWith(
            title: title,
            description: description,
            startDate: startDt,
            endDate: endDt,
            location: location,
          ),
        );
      } else {
        await repo.createEvent(
          groupId: groupId,
          title: title,
          description: description,
          startDate: startDt,
          endDate: endDt,
          location: location,
          userId: user.uid,
        );
      }
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.event != null ? 'Modifier l\'événement' : 'Nouvel événement'),
        actions: [
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
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Champ requis' : null,
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
            ],
          ),
        ),
      ),
    );
  }
}
