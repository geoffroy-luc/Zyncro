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

  /// Fin réellement applicable. BUG E15 corrigé : une règle incohérente
  /// (`count` ou `until` absent pour sa fin) ne fait plus planter
  /// (`count!` / `until!`) ; elle est lue comme sans fin.
  RecurrenceEndType get effectiveEndType => switch (endType) {
    RecurrenceEndType.count when count == null => RecurrenceEndType.forever,
    RecurrenceEndType.until when until == null => RecurrenceEndType.forever,
    _ => endType,
  };
}

/// Date de l'occurrence suivante.
///
/// ⚠️ Comportement historique conservé (BUGS_FOUND K1, E12) : jour/semaine
/// par ajout de durée (décalage possible au changement d'heure), mois/année
/// par `DateTime(y, m + 1, d)` (dérive : 31/01 → 03/03 → 03/04…).
/// Occurrence n° [n] (0 = l'ancre) d'une série ancrée au [anchor].
///
/// Calculée depuis l'ancre en heure locale « murale » :
/// - BUG K1 / E12 corrigés : une série mensuelle au 31/01 donne 31/01, 28/02,
///   31/03, 30/04 (auparavant 31/01 → 03/03 → 03/04, la dérive s'accumulait) ;
/// - BUG CA3 / E12 corrigés : une série hebdomadaire à 9 h reste à 9 h après
///   le changement d'heure (auparavant `add(Duration(days: 7))` la décalait).
DateTime nthOccurrence(DateTime anchor, RecurrenceFrequency frequency, int n) {
  DateTime at(int y, int m, int d) =>
      DateTime(y, m, d, anchor.hour, anchor.minute, anchor.second);
  int daysIn(int y, int m) => DateTime(y, m + 1, 0).day;
  switch (frequency) {
    case RecurrenceFrequency.daily:
      return at(anchor.year, anchor.month, anchor.day + n);
    case RecurrenceFrequency.weekly:
      return at(anchor.year, anchor.month, anchor.day + 7 * n);
    case RecurrenceFrequency.monthly:
      final months = anchor.month - 1 + n;
      final y = anchor.year + months ~/ 12;
      final m = months % 12 + 1;
      final d = anchor.day <= daysIn(y, m) ? anchor.day : daysIn(y, m);
      return at(y, m, d);
    case RecurrenceFrequency.yearly:
      final y = anchor.year + n;
      final m = anchor.month;
      final d = anchor.day <= daysIn(y, m) ? anchor.day : daysIn(y, m);
      return at(y, m, d);
  }
}

/// `true` tant que [occurrence] ne dépasse pas la fin de la série.
///
/// BUG K2 (3) / E14 corrigés : `until` est une **date** (enregistrée à
/// minuit) ; tout le jour `until` est inclus (auparavant une occurrence à 9 h
/// le dernier jour était exclue).
bool withinUntil(DateTime occurrence, DateTime until) => !occurrence.isAfter(
  DateTime(
    until.year,
    until.month,
    until.day + 1,
  ).subtract(const Duration(microseconds: 1)),
);
