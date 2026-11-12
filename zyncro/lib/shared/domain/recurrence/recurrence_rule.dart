enum RecurrenceFrequency { daily, weekly, monthly, yearly }

enum RecurrenceEndType { forever, count, until }

class RecurrenceRule {
  final RecurrenceFrequency frequency;
  final RecurrenceEndType endType;
  final int? count;
  final DateTime? until;

  const RecurrenceRule({
    required this.frequency,
    this.endType = RecurrenceEndType.forever,
    this.count,
    this.until,
  });
}

/// Date de l'occurrence suivante.
///
/// ⚠️ Comportement historique conservé (BUGS_FOUND K1, E12) : jour/semaine
/// par ajout de durée (décalage possible au changement d'heure), mois/année
/// par `DateTime(y, m + 1, d)` (dérive : 31/01 → 03/03 → 03/04…).
DateTime advanceOccurrence(DateTime date, RecurrenceFrequency frequency) {
  return switch (frequency) {
    RecurrenceFrequency.daily => date.add(const Duration(days: 1)),
    RecurrenceFrequency.weekly => date.add(const Duration(days: 7)),
    RecurrenceFrequency.monthly => DateTime(
      date.year,
      date.month + 1,
      date.day,
      date.hour,
      date.minute,
    ),
    RecurrenceFrequency.yearly => DateTime(
      date.year + 1,
      date.month,
      date.day,
      date.hour,
      date.minute,
    ),
  };
}
