part of 'event_form_screen.dart';

/// Choix de la récurrence.
mixin _EventFormRecurrence on _EventFormScreenStateBase {
  // ── Récurrence ────────────────────────────────────────────────────────────

  Future<void> _showRecurrencePicker() async {
    RecurrenceFrequency? selectedFreq = _recurrence?.frequency;
    RecurrenceEndType endType =
        _recurrence?.endType ?? RecurrenceEndType.forever;
    int countValue = _recurrence?.count ?? 4;
    final countController = TextEditingController(text: '$countValue');
    DateTime untilDate =
        _recurrence?.until ?? _startDate.add(const Duration(days: 30));
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
          final primary = Theme.of(ctx).colorScheme.primary;
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
                      context.l10n.calendarRepetition,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Aucune
                  ListTile(
                    leading: Icon(
                      Icons.block_outlined,
                      color: selectedFreq == null
                          ? primary
                          : context.colors.textSecondary,
                    ),
                    title: Text(context.l10n.calendarAucune),
                    trailing: selectedFreq == null
                        ? Icon(Icons.check, color: primary)
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
                            ? primary
                            : context.colors.textSecondary,
                      ),
                      title: Text(label),
                      trailing: isSelected
                          ? Icon(Icons.check, color: primary)
                          : null,
                      onTap: () => setSt(() => selectedFreq = freq),
                    );
                  }),

                  // Fin de récurrence (visible seulement si fréquence choisie)
                  if (selectedFreq != null) ...[
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: Text(
                        context.l10n.calendarFinDeLaRepetition,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    RadioGroup<RecurrenceEndType>(
                      groupValue: endType,
                      onChanged: (v) => setSt(() => endType = v!),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Toujours
                          RadioListTile<RecurrenceEndType>(
                            value: RecurrenceEndType.forever,
                            title: Text(context.l10n.calendarToujours),
                            activeColor: primary,
                          ),
                          // Nombre de fois
                          RadioListTile<RecurrenceEndType>(
                            value: RecurrenceEndType.count,
                            activeColor: primary,
                            title: endType == RecurrenceEndType.count
                                ? Row(
                                    children: [
                                      Text(context.l10n.calendarNombreDeFois),
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
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 8,
                                                ),
                                          ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          onChanged: (v) {
                                            final n = int.tryParse(v);
                                            if (n != null &&
                                                n >= 1 &&
                                                n <= 999) {
                                              setSt(() => countValue = n);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(context.l10n.calendarNombreDeFois2),
                          ),
                          // Jusqu'au
                          RadioListTile<RecurrenceEndType>(
                            value: RecurrenceEndType.until,
                            activeColor: primary,
                            title: endType == RecurrenceEndType.until
                                ? Row(
                                    children: [
                                      Text(context.l10n.calendarJusquAu),
                                      const SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: ctx,
                                            // BUG E14 corrigé : initialDate >= firstDate.
                                            initialDate:
                                                untilDate.isBefore(_startDate)
                                                ? _startDate
                                                : untilDate,
                                            firstDate: _startDate,
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null) {
                                            setSt(() {
                                              untilDate = picked;
                                              untilController.text = DateFormat(
                                                'd/M/yyyy',
                                              ).format(picked);
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: context.colors.border,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            DateFormat(
                                              'd MMM yyyy',
                                              'fr_FR',
                                            ).format(untilDate),
                                            style: TextStyle(
                                              color: primary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(context.l10n.calendarJusquAu2),
                          ),
                        ],
                      ),
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
                        style: FilledButton.styleFrom(backgroundColor: primary),
                        child: Text(context.l10n.calendarConfirmer),
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
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.repeat, size: 20, color: context.colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _recurrence != null
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
