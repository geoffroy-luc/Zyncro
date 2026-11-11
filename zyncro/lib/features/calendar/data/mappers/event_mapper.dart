import 'package:zyncro/features/calendar/domain/entities/event.dart';
import 'package:zyncro/shared/data/mappers/firestore_codec.dart';
import 'package:zyncro/shared/data/mappers/recurrence_rule_mapper.dart';

/// Champs Firestore d'un événement (`groups/{gid}/events/{id}`).
abstract final class EventFields {
  static const groupId = 'groupId';
  static const title = 'title';
  static const description = 'description';
  static const startDate = 'startDate';
  static const endDate = 'endDate';
  static const location = 'location';
  static const createdBy = 'createdBy';
  static const creatorName = 'creatorName';
  static const createdAt = 'createdAt';
  static const color = 'color';
  static const updatedBy = 'updatedBy';
  static const recurrence = 'recurrence';
  static const participantIds = 'participantIds';
}

abstract final class EventMapper {
  static Event fromFirestore(String id, Map<String, dynamic> map) {
    return Event(
      id: id,
      groupId: map[EventFields.groupId] as String,
      title: map[EventFields.title] as String,
      description: map[EventFields.description] as String?,
      startDate: FirestoreCodec.toDate(map[EventFields.startDate]),
      endDate: FirestoreCodec.toDateOrNull(map[EventFields.endDate]),
      location: map[EventFields.location] as String?,
      createdBy: map[EventFields.createdBy] as String,
      creatorName: map[EventFields.creatorName] as String?,
      createdAt: FirestoreCodec.toDate(map[EventFields.createdAt]),
      color: map[EventFields.color] as String?,
      updatedBy: map[EventFields.updatedBy] as String?,
      recurrence: map[EventFields.recurrence] != null
          ? RecurrenceRuleMapper.fromFirestore(
              map[EventFields.recurrence] as Map<String, dynamic>,
            )
          : null,
      participantIds: FirestoreCodec.stringList(
        map[EventFields.participantIds],
      ),
    );
  }

  /// ⚠️ Les clés nulles `color` / `recurrence` sont OMISES : combiné à
  /// `update()`, on ne peut pas effacer ces champs en édition (BUGS_FOUND K3,
  /// CA2) — comportement historique conservé.
  static Map<String, dynamic> toFirestore(Event event) => {
    EventFields.groupId: event.groupId,
    EventFields.title: event.title,
    EventFields.description: event.description,
    EventFields.startDate: FirestoreCodec.fromDate(event.startDate),
    EventFields.endDate: event.endDate != null
        ? FirestoreCodec.fromDate(event.endDate!)
        : null,
    EventFields.location: event.location,
    EventFields.createdBy: event.createdBy,
    if (event.creatorName != null) EventFields.creatorName: event.creatorName,
    EventFields.createdAt: FirestoreCodec.fromDate(event.createdAt),
    if (event.color != null) EventFields.color: event.color,
    if (event.updatedBy != null) EventFields.updatedBy: event.updatedBy,
    if (event.recurrence != null)
      EventFields.recurrence: RecurrenceRuleMapper.toFirestore(
        event.recurrence!,
      ),
    EventFields.participantIds: event.participantIds,
  };
}
