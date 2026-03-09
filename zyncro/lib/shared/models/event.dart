import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String groupId;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final String? location;
  final String createdBy;
  final DateTime createdAt;

  const Event({
    required this.id,
    required this.groupId,
    required this.title,
    this.description,
    required this.startDate,
    this.endDate,
    this.location,
    required this.createdBy,
    required this.createdAt,
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
      createdAt: (map['createdAt'] as Timestamp).toDate(),
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
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Event copyWith({
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
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
      createdAt: createdAt,
    );
  }
}
