import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zyncro/core/utils/firestore_stream_extensions.dart';
import 'package:zyncro/shared/models/tab_settings.dart';

class TabSettingsRepository {
  TabSettingsRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String groupId) => _db
      .collection('groups')
      .doc(groupId)
      .collection('config')
      .doc('tabSettings');

  Stream<TabSettings> watchSettings(String groupId) {
    return _doc(groupId)
        .snapshots()
        .map((snap) {
          if (!snap.exists || snap.data() == null) return TabSettings.defaults;
          return TabSettings.fromMap(snap.data()!);
        })
        .surfacePermissionDenied('watchSettings');
  }

  /// Écrit uniquement les champs qui diffèrent entre [from] (l'état à partir
  /// duquel l'utilisateur a fait sa modification) et [to].
  ///
  /// `set(merge: true)` conserve le document existant : les champs non
  /// modifiés — y compris ceux qu'un autre membre vient de changer, ou les
  /// valeurs réelles quand [from] vaut les défauts pendant un chargement —
  /// ne sont pas touchés.
  Future<void> updateSettings(
    String groupId, {
    required TabSettings from,
    required TabSettings to,
  }) async {
    final changes = from.changedFieldsTo(to);
    if (changes.isEmpty) return;
    await _doc(groupId).set(changes, SetOptions(merge: true));
  }
}
