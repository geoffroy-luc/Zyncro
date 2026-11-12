import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';

class Event {
  final String id;
  final String groupId;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final String? location;
  final String createdBy;
  final String? creatorName;
  final DateTime createdAt;
  final String? color;
  final String? updatedBy;
  final RecurrenceRule? recurrence;
  final List<String> participantIds;

  /// Occurrence d'une série uniquement (calculé, jamais stocké) : début de
  /// l'ancre de la série et rang de l'occurrence (0 = première).
  final DateTime? seriesStart;
  final int? occurrenceIndex;

  bool get isSeriesOccurrence =>
      recurrence != null && seriesStart != null && occurrenceIndex != null;

  const Event({
    required this.id,
    required this.groupId,
    required this.title,
    this.description,
    required this.startDate,
    this.endDate,
    this.location,
    required this.createdBy,
    this.creatorName,
    required this.createdAt,
    this.color,
    this.updatedBy,
    this.recurrence,
    this.participantIds = const [],
    this.seriesStart,
    this.occurrenceIndex,
  });

  Event copyWith({
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    String? color,
    String? updatedBy,
    RecurrenceRule? recurrence,
    bool clearRecurrence = false,
    List<String>? participantIds,
    // BUG CA1 / K3 (b) corrigés : un champ vidé dans le formulaire peut
    // désormais être effacé (auparavant `?? this.x` le conservait).
    bool clearDescription = false,
    bool clearEndDate = false,
    bool clearLocation = false,
    bool clearColor = false,
  }) {
    return Event(
      id: id,
      groupId: groupId,
      title: title ?? this.title,
      description: clearDescription ? null : description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      location: clearLocation ? null : location ?? this.location,
      createdBy: createdBy,
      creatorName: creatorName,
      createdAt: createdAt,
      color: clearColor ? null : color ?? this.color,
      updatedBy: updatedBy ?? this.updatedBy,
      recurrence: clearRecurrence ? null : recurrence ?? this.recurrence,
      participantIds: participantIds ?? this.participantIds,
      seriesStart: seriesStart,
      occurrenceIndex: occurrenceIndex,
    );
  }
}
