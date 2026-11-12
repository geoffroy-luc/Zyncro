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
  }) {
    return Event(
      id: id,
      groupId: groupId,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      createdBy: createdBy,
      creatorName: creatorName,
      createdAt: createdAt,
      color: color ?? this.color,
      updatedBy: updatedBy ?? this.updatedBy,
      recurrence: clearRecurrence ? null : recurrence ?? this.recurrence,
      participantIds: participantIds ?? this.participantIds,
    );
  }
}
