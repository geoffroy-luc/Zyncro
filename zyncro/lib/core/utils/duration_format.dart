/// Durée affichée `mm:ss`, ou `h:mm:ss` au-delà d'une heure.
///
/// BUG M17 corrigé : 1 h 05 s'affichait « 05:00 » (les heures étaient
/// perdues par `inMinutes.remainder(60)`).
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
