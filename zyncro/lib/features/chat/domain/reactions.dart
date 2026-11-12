/// Nouvelle carte de réactions après un appui sur [key] par [userId].
///
/// Les votes d'un sondage sont des clés numériques ("0", "1"…), les réactions
/// des emojis. En mode [exclusive], l'utilisateur est retiré des autres clés
/// de même nature seulement : un vote n'efface plus les emojis (BUG C8).
/// Les listes vides sont supprimées.
Map<String, List<String>> applyReaction(
  Map<String, List<String>> reactions, {
  required String key,
  required String userId,
  required bool hasReacted,
  required bool exclusive,
}) {
  final next = {
    for (final e in reactions.entries) e.key: [...e.value],
  };
  if (exclusive) {
    final isVote = int.tryParse(key) != null;
    for (final k in next.keys) {
      if ((int.tryParse(k) != null) == isVote) next[k]!.remove(userId);
    }
  }
  if (!hasReacted) next[key] = [...?next[key], userId];
  next.removeWhere((_, v) => v.isEmpty);
  return next;
}
