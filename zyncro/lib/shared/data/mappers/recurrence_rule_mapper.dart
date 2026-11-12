import 'package:zyncro/shared/data/mappers/firestore_codec.dart';
import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';

/// Champs Firestore d'une règle de récurrence (événements et dépenses).
abstract final class RecurrenceRuleFields {
  static const frequency = 'frequency';
  static const endType = 'endType';
  static const count = 'count';
  static const until = 'until';
}

abstract final class RecurrenceRuleMapper {
  static RecurrenceRule fromFirestore(Map<String, dynamic> map) {
    return RecurrenceRule(
      frequency: RecurrenceFrequency.values.byName(
        map[RecurrenceRuleFields.frequency] as String,
      ),
      endType: RecurrenceEndType.values.byName(
        (map[RecurrenceRuleFields.endType] as String?) ?? 'forever',
      ),
      count: map[RecurrenceRuleFields.count] as int?,
      until: FirestoreCodec.toDateOrNull(map[RecurrenceRuleFields.until]),
    );
  }

  static Map<String, dynamic> toFirestore(RecurrenceRule rule) => {
    RecurrenceRuleFields.frequency: rule.frequency.name,
    RecurrenceRuleFields.endType: rule.endType.name,
    if (rule.count != null) RecurrenceRuleFields.count: rule.count,
    if (rule.until != null)
      RecurrenceRuleFields.until: FirestoreCodec.fromDate(rule.until!),
  };
}
