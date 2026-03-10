import '../../../../shared/models/message.dart';

abstract interface class IMessagesRepository {
  Stream<List<Message>> watchMessages(String groupId);
  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String content,
  });
  Future<void> editMessage({
    required String groupId,
    required String messageId,
    required String content,
  });
  Future<void> deleteMessage({
    required String groupId,
    required String messageId,
  });

  /// Enregistre que l'utilisateur est en train d'écrire.
  Future<void> setTyping({
    required String groupId,
    required String userId,
    required String userName,
  });

  /// Supprime le statut "en train d'écrire" de l'utilisateur.
  Future<void> clearTyping({required String groupId, required String userId});

  /// Stream des noms des utilisateurs en train d'écrire (hors [currentUserId]).
  Stream<List<String>> watchTyping({
    required String groupId,
    required String currentUserId,
  });

  /// Envoie un message système (action automatique).
  Future<void> sendSystemMessage({
    required String groupId,
    required String userId,
    required String content,
    required String notifScreen,
  });
}
