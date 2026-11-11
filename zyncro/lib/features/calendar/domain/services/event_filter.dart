import 'package:zyncro/features/calendar/domain/entities/event.dart';

/// Recherche et filtres du calendrier (brique de la future couche de
/// recherche / filtres par onglet).
class EventFilter {
  const EventFilter({
    this.search = '',
    this.participantIds = const {},
    this.recurrenceOnly = false,
  });

  /// Texte recherché dans le titre et le lieu (insensible à la casse).
  final String search;

  /// Au moins un de ces participants (vide = pas de filtre).
  final Set<String> participantIds;

  /// Seulement les événements récurrents.
  final bool recurrenceOnly;

  bool get isActive => participantIds.isNotEmpty || recurrenceOnly;

  List<Event> apply(List<Event> events) {
    var result = events;
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result
          .where(
            (e) =>
                e.title.toLowerCase().contains(q) ||
                (e.location?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    if (participantIds.isNotEmpty) {
      result = result
          .where((e) => e.participantIds.any(participantIds.contains))
          .toList();
    }
    if (recurrenceOnly) {
      result = result.where((e) => e.recurrence != null).toList();
    }
    return result;
  }
}
