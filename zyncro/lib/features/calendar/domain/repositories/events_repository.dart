import 'package:zyncro/features/calendar/domain/entities/event.dart';
import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';

abstract interface class EventsRepository {
  Stream<List<Event>> watchEvents(String groupId);
  Future<Event> createEvent({
    required String groupId,
    required String title,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    String? location,
    required String userId,
    String? color,
    RecurrenceRule? recurrence,
    List<String> participantIds = const [],
    String? creatorName,
  });
  Future<void> updateEvent(String groupId, Event event);
  Future<void> deleteEvent(String groupId, String eventId);
}
