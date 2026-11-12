/// Pagination « fenêtre live + pages anciennes », sans trou.
///
/// La fenêtre live contient les [pageSize] éléments les plus récents (flux
/// temps réel). Les pages plus anciennes sont chargées à la demande
/// ([cursor], [addOlderPage]). Un élément poussé hors de la fenêtre par un
/// nouvel arrivant est conservé dans les pages anciennes. C'est précisément
/// ce qui manque au chat (BUGS_FOUND C1). Un élément qui disparaît alors
/// qu'il est plus récent que le plus ancien de la fenêtre a été supprimé.
///
/// Limite assumée : les pages anciennes sont des instantanés (une suppression
/// ou modification y apparaît à la réouverture), comme dans le chat.
class LiveWindowPager<T> {
  LiveWindowPager({
    required this.pageSize,
    required this.idOf,
    required this.timeOf,
  });

  final int pageSize;
  final String Function(T) idOf;
  final DateTime Function(T) timeOf;

  List<T> _live = const [];
  List<T> _older = const [];
  bool _liveFull = false;
  bool _olderExhausted = false;

  /// Tous les éléments, du plus récent au plus ancien, sans doublon.
  List<T> get items {
    final liveIds = {for (final e in _live) idOf(e)};
    return [..._live, ..._older.where((e) => !liveIds.contains(idOf(e)))];
  }

  /// Une fenêtre live incomplète contient déjà tout.
  bool get hasMore => _liveFull && !_olderExhausted;

  /// Borne (exclue) de la page suivante, `null` si rien n'est chargé.
  DateTime? get cursor {
    final all = items;
    return all.isEmpty ? null : timeOf(all.last);
  }

  void onLiveSnapshot(List<T> snapshot) {
    final full = snapshot.length >= pageSize;
    if (full && snapshot.isNotEmpty) {
      final ids = {for (final e in snapshot) idOf(e)};
      final oldest = timeOf(snapshot.last);
      final fellOff = [
        for (final e in _live)
          if (!ids.contains(idOf(e)) && !timeOf(e).isAfter(oldest)) e,
      ];
      if (fellOff.isNotEmpty) {
        final fellIds = {for (final e in fellOff) idOf(e)};
        _older = [
          ...fellOff,
          ..._older.where((e) => !fellIds.contains(idOf(e))),
        ];
      }
    }
    _live = snapshot;
    _liveFull = full;
  }

  void addOlderPage(List<T> page) {
    final known = {
      for (final e in _live) idOf(e),
      for (final e in _older) idOf(e),
    };
    _older = [..._older, ...page.where((e) => !known.contains(idOf(e)))];
    if (page.length < pageSize) _olderExhausted = true;
  }
}
