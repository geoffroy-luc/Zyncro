/// Noms des collections et chemins Firestore — SOURCE UNIQUE.
///
/// ⚠️ Contrat de données avec les versions installées : ne jamais renommer
/// une valeur sans plan de migration (docs/refactor/PLAN.md §1). Les mêmes
/// chemins sont utilisés par les Cloud Functions (functions/src/shared/paths.ts)
/// et par les règles (firestore.rules, storage.rules).
abstract final class FirestoreCollections {
  static const users = 'users';
  static const groups = 'groups';
  static const inviteCodes = 'invite_codes';
  static const appConfig = 'config';

  // Sous-collections d'un groupe
  static const members = 'members';
  static const messages = 'messages';
  static const typing = 'typing';
  static const expenses = 'expenses';
  static const events = 'events';
  static const notes = 'notes';
  static const groupConfig = 'config';
}

/// Documents à identifiant fixe.
abstract final class FirestoreDocIds {
  static const appVersion = 'app_version';
  static const tabSettings = 'tabSettings';
}

/// Chemins Storage (cf. storage.rules).
abstract final class StoragePaths {
  static String profilePhoto(String uid) => 'profile_photos/$uid.jpg';
  static String groupPhoto(String groupId) => 'group_photos/$groupId.jpg';
  static String chatBackground(String groupId) =>
      'chat_backgrounds/$groupId.jpg';
  static String audio(String groupId, String messageId) =>
      'audio/$groupId/$messageId.m4a';
  static String media(String groupId, String fileName) =>
      'media/$groupId/$fileName';
}
