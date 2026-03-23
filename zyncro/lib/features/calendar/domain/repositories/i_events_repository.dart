import '../../../../shared/models/event.dart';
import '../../../../shared/models/recurrence_rule.dart';

abstract interface class IEventsRepository {
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
  });
  Future<void> updateEvent(String groupId, Event event);
  Future<void> deleteEvent(String groupId, String eventId);
}
