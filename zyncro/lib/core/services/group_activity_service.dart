import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/group.dart';

/// Score d'activité local par groupe, avec décroissance temporelle.
///
/// Objectif : classer les groupes « sur lesquels l'utilisateur est le plus
/// actif » pour alimenter les raccourcis de partage direct. Tout est stocké
/// localement (SharedPreferences) — aucune lecture Firestore supplémentaire.
///
/// Chaque interaction (ouvrir un groupe, y partager un média…) ajoute du poids.
/// Le score décroît avec une demi-vie, si bien qu'un groupe très actif il y a
/// deux mois retombe naturellement derrière un groupe actif cette semaine.
class GroupActivityService {
  static const _halfLife = Duration(days: 14);

  static String _key(String uid) => 'group_activity_scores_$uid';

  /// Score brut mémorisé + horodatage de la dernière mise à jour, par groupe.
  static Future<Map<String, ({double score, int ts})>> _load(
    SharedPreferences prefs,
    String uid,
  ) async {
    final raw = prefs.getString(_key(uid));
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((id, v) {
        final m = v as Map<String, dynamic>;
        return MapEntry(id, (
          score: (m['score'] as num).toDouble(),
          ts: m['ts'] as int,
        ));
      });
    } catch (_) {
      return {};
    }
  }

  static Future<void> _save(
    SharedPreferences prefs,
    String uid,
    Map<String, ({double score, int ts})> data,
  ) async {
    final encoded = jsonEncode(
      data.map((id, v) => MapEntry(id, {'score': v.score, 'ts': v.ts})),
    );
    await prefs.setString(_key(uid), encoded);
  }

  /// Applique la décroissance d'un score depuis [fromTs] jusqu'à [nowMs].
  static double _decayed(double score, int fromTs, int nowMs) {
    final elapsedMs = (nowMs - fromTs).clamp(0, 1 << 62);
    final halfLives = elapsedMs / _halfLife.inMilliseconds;
    return score * math.pow(0.5, halfLives);
  }

  /// Enregistre une interaction avec [groupId] (poids par défaut 1).
  static Future<void> recordInteraction(
    String uid,
    String groupId, {
    double weight = 1.0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = await _load(prefs, uid);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = data[groupId];
    final base = existing == null
        ? 0.0
        : _decayed(existing.score, existing.ts, now);
    data[groupId] = (score: base + weight, ts: now);
    await _save(prefs, uid, data);
  }

  /// Retourne [groups] triés par activité décroissante.
  ///
  /// Les groupes sans historique gardent leur ordre relatif d'entrée (stable),
  /// derrière ceux qui ont un score.
  static Future<List<Group>> rank(String uid, List<Group> groups) async {
    if (groups.isEmpty) return const [];
    final prefs = await SharedPreferences.getInstance();
    final data = await _load(prefs, uid);
    final now = DateTime.now().millisecondsSinceEpoch;

    final scores = <String, double>{};
    for (final g in groups) {
      final e = data[g.id];
      scores[g.id] = e == null ? 0.0 : _decayed(e.score, e.ts, now);
    }

    final indexed = groups.asMap().entries.toList();
    indexed.sort((a, b) {
      final byScore = scores[b.value.id]!.compareTo(scores[a.value.id]!);
      if (byScore != 0) return byScore;
      return a.key.compareTo(b.key); // stable : conserve l'ordre d'origine
    });
    return indexed.map((e) => e.value).toList();
  }
}
