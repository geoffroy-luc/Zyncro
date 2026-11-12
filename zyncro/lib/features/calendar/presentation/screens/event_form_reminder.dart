part of 'event_form_screen.dart';

/// Rappel local (notification) de l'événement.
mixin _EventFormReminder on _EventFormScreenStateBase {
  Future<void> _loadReminder(String eventId) async {
    final minutes = await ReminderService.getReminderMinutes(eventId);
    if (mounted) setState(() => _reminderMinutes = minutes);
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
                final primary = Theme.of(ctx).colorScheme.primary;
                return ListTile(
                  leading: Icon(
                    icon,
                    color: selected ? primary : context.colors.textSecondary,
                  ),
                  title: Text(label),
                  trailing: selected ? Icon(Icons.check, color: primary) : null,
                  onTap: () {
                    setState(() => _reminderMinutes = minutes);
                    Navigator.pop(ctx);
                  },
                );
              }),
              ListTile(
                leading: Icon(
                  Icons.tune_outlined,
                  color: context.colors.textSecondary,
                ),
                title: const Text('Personnalisé…'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_showCustomReminderDialog());
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
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.notifications_outlined,
              size: 20,
              color: context.colors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _reminderLabel,
                style: TextStyle(
                  color: _reminderMinutes != null
                      ? context.colors.textPrimary
                      : context.colors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
