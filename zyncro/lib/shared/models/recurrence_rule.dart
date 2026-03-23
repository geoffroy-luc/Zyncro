import 'package:cloud_firestore/cloud_firestore.dart';

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

  Map<String, dynamic> toMap() => {
        'frequency': frequency.name,
        'endType': endType.name,
        if (count != null) 'count': count,
        if (until != null) 'until': Timestamp.fromDate(until!),
      };

  factory RecurrenceRule.fromMap(Map<String, dynamic> map) {
    return RecurrenceRule(
      frequency: RecurrenceFrequency.values.byName(map['frequency'] as String),
      endType: RecurrenceEndType.values
          .byName((map['endType'] as String?) ?? 'forever'),
      count: map['count'] as int?,
      until: map['until'] != null
          ? (map['until'] as Timestamp).toDate()
          : null,
    );
  }

  String get label {
    final freqLabel = switch (frequency) {
      RecurrenceFrequency.daily => 'Tous les jours',
      RecurrenceFrequency.weekly => 'Toutes les semaines',
      RecurrenceFrequency.monthly => 'Tous les mois',
      RecurrenceFrequency.yearly => 'Tous les ans',
    };
    final endLabel = switch (endType) {
      RecurrenceEndType.forever => '',
      RecurrenceEndType.count => ' · $count fois',
      RecurrenceEndType.until =>
        ' · jusqu\'au ${until!.day}/${until!.month}/${until!.year}',
    };
    return '$freqLabel$endLabel';
  }
}
