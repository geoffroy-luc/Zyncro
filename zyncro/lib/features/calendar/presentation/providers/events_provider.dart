import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/events_repository.dart';
import '../../domain/repositories/i_events_repository.dart';
import '../../../../shared/models/event.dart';
import '../../../groups/presentation/providers/groups_provider.dart';

final eventsRepositoryProvider = Provider<IEventsRepository>(
  (_) => EventsRepository(),
);

final eventsProvider = StreamProvider<List<Event>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return Stream.value([]);
  return ref.watch(eventsRepositoryProvider).watchEvents(groupId);
});
