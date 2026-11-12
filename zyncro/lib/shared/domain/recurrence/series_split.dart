import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';

/// Édition / suppression d'une occurrence d'une série (dépenses, événements),
/// sans nouveau champ en base : on ne joue que sur `count` / `until`, que les
/// versions déjà publiées savent lire.
///
/// BUGS E8 / E9 / K2 / CA6 : auparavant, enregistrer une occurrence
/// réécrivait l'ancre de la série à la date de l'occurrence (les occurrences
/// passées disparaissaient) et supprimer une occurrence supprimait la série.

/// Portée choisie par l'utilisateur.
enum SeriesScope { thisAndFollowing, wholeSeries }

/// Règle de la série d'origine arrêtée juste avant l'occurrence n° [index]
/// (qui tombe le [occurrence]). `null` si [index] vaut 0 : il ne reste rien
/// avant, c'est toute la série qui est concernée.
RecurrenceRule? truncateBefore(
  RecurrenceRule rule, {
  required int index,
  required DateTime occurrence,
}) {
  if (index <= 0) return null;
  if (rule.endType == RecurrenceEndType.count) {
    return RecurrenceRule(
      frequency: rule.frequency,
      endType: RecurrenceEndType.count,
      count: index,
    );
  }
  // Fin du jour précédent : exclue l'occurrence avec la règle « jour
  // inclus » comme avec la comparaison stricte des versions publiées.
  return RecurrenceRule(
    frequency: rule.frequency,
    endType: RecurrenceEndType.until,
    until: DateTime(
      occurrence.year,
      occurrence.month,
      occurrence.day,
      0,
      0,
      -1,
    ),
  );
}

/// Règle d'une nouvelle série qui reprend à l'occurrence n° [index] de
/// [rule] : même fréquence et même fin (le nombre restant si `count`).
RecurrenceRule continueFrom(RecurrenceRule rule, {required int index}) {
  if (rule.endType != RecurrenceEndType.count) return rule;
  final remaining = (rule.count ?? 1) - index;
  return RecurrenceRule(
    frequency: rule.frequency,
    endType: RecurrenceEndType.count,
    count: remaining < 1 ? 1 : remaining,
  );
}

/// Ancre de la série après avoir déplacé l'occurrence [occurrence] au
/// [edited] : le même décalage est appliqué à l'ancre [seriesStart] (une
/// occurrence non déplacée laisse l'ancre intacte).
DateTime shiftAnchor(
  DateTime seriesStart, {
  required DateTime occurrence,
  required DateTime edited,
}) => seriesStart.add(edited.difference(occurrence));

bool sameRule(RecurrenceRule? a, RecurrenceRule? b) =>
    a?.frequency == b?.frequency &&
    a?.endType == b?.endType &&
    a?.count == b?.count &&
    a?.until == b?.until;
