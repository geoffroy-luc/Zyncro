import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/i_events_repository.dart';
import '../../../../shared/models/event.dart';

class EventsRepository implements IEventsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String groupId) =>
      _db.collection('groups').doc(groupId).collection('events');

  @override
  Stream<List<Event>> watchEvents(String groupId) {
    return _col(groupId)
        .orderBy('startDate')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Event.fromMap(doc.id, doc.data())).toList());
  }

  @override
  Future<Event> createEvent({
    required String groupId,
    required String title,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    String? location,
    required String userId,
  }) async {
    final ref = _col(groupId).doc();
    final event = Event(
      id: ref.id,
      groupId: groupId,
      title: title,
      description: description,
      startDate: startDate,
      endDate: endDate,
      location: location,
      createdBy: userId,
      createdAt: DateTime.now(),
    );
    await ref.set(event.toMap());
    return event;
  }

  @override
  Future<void> updateEvent(String groupId, Event event) async {
    await _col(groupId).doc(event.id).update(event.toMap());
  }

  @override
  Future<void> deleteEvent(String groupId, String eventId) async {
    await _col(groupId).doc(eventId).delete();
  }
}
