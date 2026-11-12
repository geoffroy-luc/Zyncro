/// Entrées de premier niveau de [after] qui diffèrent de [before]
/// (comparaison profonde des listes et cartes, `==` sinon : les `Timestamp`
/// se comparent par valeur). Sert aux `update()` champ par champ, qui ne
/// réécrivent pas les champs modifiés entre-temps par un autre membre
/// (BUGS_FOUND G1, G11).
Map<String, dynamic> changedEntries(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) => {
  for (final entry in after.entries)
    if (!jsonEquals(before[entry.key], entry.value)) entry.key: entry.value,
};

bool jsonEquals(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !jsonEquals(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}
