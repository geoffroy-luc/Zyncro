import '../../../../shared/models/event.dart';

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
  });
  Future<void> updateEvent(String groupId, Event event);
  Future<void> deleteEvent(String groupId, String eventId);
}
