/// Limite les écritures « en train d'écrire » : la première frappe est
/// envoyée tout de suite, puis au plus une écriture par [interval].
///
/// L'indicateur des autres membres reste identique : un document de frappe
/// compte s'il a moins de 6 s (seuil de lecture), il est rafraîchi au moins
/// toutes les [interval] (2 s) tant que l'on tape, et supprimé 4 s après la
/// dernière frappe, comme avant. Auparavant : une écriture Firestore par
/// frappe.
class TypingThrottle {
  TypingThrottle({
    this.interval = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration interval;
  final DateTime Function() _clock;
  DateTime? _lastSent;

  /// `true` si l'écriture doit partir maintenant (et la mémorise).
  bool shouldSend() {
    final now = _clock();
    final last = _lastSent;
    if (last != null && now.difference(last) < interval) return false;
    _lastSent = now;
    return true;
  }

  /// Après suppression du document de frappe : la prochaine frappe repart
  /// immédiatement.
  void reset() => _lastSent = null;
}
