import 'package:cloud_firestore/cloud_firestore.dart';
import 'recurrence_rule.dart';

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
  });

  factory Event.fromMap(String id, Map<String, dynamic> map) {
    return Event(
      id: id,
      groupId: map['groupId'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: map['endDate'] != null
          ? (map['endDate'] as Timestamp).toDate()
          : null,
      location: map['location'] as String?,
      createdBy: map['createdBy'] as String,
      creatorName: map['creatorName'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      color: map['color'] as String?,
      updatedBy: map['updatedBy'] as String?,
      recurrence: map['recurrence'] != null
          ? RecurrenceRule.fromMap(map['recurrence'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'title': title,
      'description': description,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'location': location,
      'createdBy': createdBy,
      if (creatorName != null) 'creatorName': creatorName,
      'createdAt': Timestamp.fromDate(createdAt),
      if (color != null) 'color': color,
      if (updatedBy != null) 'updatedBy': updatedBy,
      if (recurrence != null) 'recurrence': recurrence!.toMap(),
    };
  }

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
    );
  }
}
