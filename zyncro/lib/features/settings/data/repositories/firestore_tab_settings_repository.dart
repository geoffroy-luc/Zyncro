import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zyncro/core/firebase/firestore_paths.dart';
import 'package:zyncro/core/utils/firestore_stream_extensions.dart';
import 'package:zyncro/features/settings/data/mappers/tab_settings_mapper.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/domain/repositories/tab_settings_repository.dart';

class FirestoreTabSettingsRepository implements TabSettingsRepository {
  FirestoreTabSettingsRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String groupId) => _db
      .collection(FirestoreCollections.groups)
      .doc(groupId)
      .collection(FirestoreCollections.groupConfig)
      .doc(FirestoreDocIds.tabSettings);

  @override
  Stream<TabSettings> watchSettings(String groupId) {
    return _doc(groupId)
        .snapshots()
        .map((snap) {
          if (!snap.exists || snap.data() == null) return TabSettings.defaults;
          return TabSettingsMapper.fromFirestore(snap.data()!);
        })
        .surfacePermissionDenied('watchSettings');
  }

  /// `set(merge: true)` conserve le document existant : les champs non
  /// modifiés — y compris ceux qu'un autre membre vient de changer, ou les
  /// valeurs réelles quand [from] vaut les défauts pendant un chargement —
  /// ne sont pas touchés.
  @override
  Future<void> updateSettings(
    String groupId, {
    required TabSettings from,
    required TabSettings to,
  }) async {
    final changes = TabSettingsMapper.changedFields(from, to);
    if (changes.isEmpty) return;
    await _doc(groupId).set(changes, SetOptions(merge: true));
  }
}
