import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';

/// Libellé affiché d'une règle de récurrence (formulaires d'événement et de
/// dépense). Texte d'interface : vit côté présentation, pas dans le domaine.
extension RecurrenceRuleLabel on RecurrenceRule {
  String get label {
    final freqLabel = switch (frequency) {
      RecurrenceFrequency.daily => 'Tous les jours',
      RecurrenceFrequency.weekly => 'Toutes les semaines',
      RecurrenceFrequency.monthly => 'Tous les mois',
      RecurrenceFrequency.yearly => 'Tous les ans',
    };
    final endLabel = switch (effectiveEndType) {
      RecurrenceEndType.forever => '',
      RecurrenceEndType.count => ' · $count fois',
      RecurrenceEndType.until =>
        ' · jusqu\'au ${until!.day}/${until!.month}/${until!.year}',
    };
    return '$freqLabel$endLabel';
  }
}
