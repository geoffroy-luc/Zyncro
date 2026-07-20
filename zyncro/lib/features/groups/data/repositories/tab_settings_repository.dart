import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_extensions.dart';
import '../../../../shared/models/tab_settings.dart';

class TabSettingsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  Future<void> updateSettings(String groupId, TabSettings settings) async {
    await _doc(groupId).set(settings.toMap(), SetOptions(merge: true));
  }
}
