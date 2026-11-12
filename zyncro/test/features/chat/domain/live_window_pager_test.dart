import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/chat/domain/live_window_pager.dart';

typedef _Item = ({String id, int t});

final _t0 = DateTime(2026);

LiveWindowPager<_Item> _pager(int pageSize) => LiveWindowPager<_Item>(
  pageSize: pageSize,
  idOf: (e) => e.id,
  timeOf: (e) => _t0.add(Duration(minutes: e.t)),
);

/// Éléments t = from, from-1, …, (du plus récent au plus ancien).
List<_Item> _desc(int from, int count) => [
  for (var t = from; t > from - count; t--) (id: 'm$t', t: t),
];

List<String> _ids(LiveWindowPager<_Item> p) => [for (final e in p.items) e.id];

void main() {
  test('fenêtre incomplète : tout est là, rien de plus à charger', () {
    final p = _pager(3)..onLiveSnapshot(_desc(2, 2));
    expect(_ids(p), ['m2', 'm1']);
    expect(p.hasMore, isFalse);
  });

  test('fenêtre pleine puis page ancienne, curseur = plus ancien', () {
    final p = _pager(3)..onLiveSnapshot(_desc(10, 3));
    expect(p.hasMore, isTrue);
    expect(p.cursor, _t0.add(const Duration(minutes: 8)));
    p.addOlderPage(_desc(7, 3));
    expect(_ids(p), ['m10', 'm9', 'm8', 'm7', 'm6', 'm5']);
    expect(p.hasMore, isTrue);
    p.addOlderPage(_desc(4, 1));
    expect(p.hasMore, isFalse);
  });

  test('nouvel arrivant : l’élément poussé hors fenêtre est conservé (C1)', () {
    final p = _pager(3)
      ..onLiveSnapshot(_desc(10, 3))
      ..addOlderPage(_desc(7, 3))
      ..onLiveSnapshot(_desc(11, 3)); // m8 sort de la fenêtre
    expect(_ids(p), ['m11', 'm10', 'm9', 'm8', 'm7', 'm6', 'm5']);
  });

  test('plusieurs arrivants d’un coup, sans page chargée', () {
    final p = _pager(3)
      ..onLiveSnapshot(_desc(10, 3))
      ..onLiveSnapshot(_desc(12, 3)); // m9 et m8 sortent
    expect(_ids(p), ['m12', 'm11', 'm10', 'm9', 'm8']);
    expect(p.cursor, _t0.add(const Duration(minutes: 8)));
  });

  test('suppression dans la fenêtre : retirée, la fenêtre se recomble', () {
    final p = _pager(3)
      ..onLiveSnapshot(_desc(10, 3))
      ..addOlderPage(_desc(7, 3))
      ..onLiveSnapshot([
        (id: 'm10', t: 10),
        (id: 'm8', t: 8),
        (id: 'm7', t: 7),
      ]); // m9 supprimé, m7 remonte dans la fenêtre
    expect(_ids(p), ['m10', 'm8', 'm7', 'm6', 'm5']);
  });

  test('suppression qui rend la fenêtre incomplète : plus de page', () {
    final p = _pager(3)
      ..onLiveSnapshot(_desc(10, 3))
      ..onLiveSnapshot(_desc(10, 2));
    expect(_ids(p), ['m10', 'm9']);
    expect(p.hasMore, isFalse);
  });

  test('page ancienne déjà connue : pas de doublon', () {
    final p = _pager(3)
      ..onLiveSnapshot(_desc(10, 3))
      ..onLiveSnapshot(_desc(11, 3))
      ..addOlderPage(_desc(8, 3));
    expect(_ids(p), ['m11', 'm10', 'm9', 'm8', 'm7', 'm6']);
  });
}
