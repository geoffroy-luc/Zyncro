import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/features/calendar/data/repositories/events_repository.dart';
import 'package:zyncro/features/calendar/domain/repositories/i_events_repository.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/shared/models/event.dart';
import 'package:zyncro/shared/utils/recurrence_utils.dart';

final eventsRepositoryProvider = Provider<IEventsRepository>(
  (_) => EventsRepository(),
);

/// Raw events from Firestore (base events only, recurring not expanded).
final eventsProvider = StreamProvider<List<Event>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return Stream.value([]);
  return ref.watch(eventsRepositoryProvider).watchEvents(groupId);
});

/// Expanded events: recurring events are inflated into individual instances.
final expandedEventsProvider = Provider<AsyncValue<List<Event>>>((ref) {
  return ref.watch(eventsProvider).whenData(expandEvents);
});
