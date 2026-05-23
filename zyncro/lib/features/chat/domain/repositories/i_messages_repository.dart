import '../../../../shared/models/message.dart';

abstract interface class IMessagesRepository {
  Stream<List<Message>> watchMessages(String groupId);
  Stream<List<Message>> watchMediaMessages(String groupId);
  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String content,
    String? replyToId,
    String? replyToSenderName,
    String? replyToContent,
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

  /// Envoie un clip audio dans le groupe.
  Future<void> sendAudio({
    required String groupId,
    required String senderId,
    required String senderName,
    required String filePath,
    required int durationSeconds,
  });

  /// Envoie une photo ou une vidéo dans le groupe.
  Future<void> sendMedia({
    required String groupId,
    required String senderId,
    required String senderName,
    required String filePath,
    required String mimeType,
    String? replyToId,
    String? replyToSenderName,
    String? replyToContent,
  });

  /// Envoie plusieurs médias (jusqu'à 10) en un seul message album.
  Future<void> sendMultipleMedia({
    required String groupId,
    required String senderId,
    required String senderName,
    required List<({String filePath, String mimeType})> medias,
    String? replyToId,
    String? replyToSenderName,
    String? replyToContent,
  });

  /// Envoie un sondage dans le groupe.
  Future<void> sendPoll({
    required String groupId,
    required String senderId,
    required String senderName,
    required String question,
    required List<String> options,
    bool multipleChoice = false,
  });

  /// Modifie un sondage existant (réinitialise les votes).
  Future<void> editPoll({
    required String groupId,
    required String messageId,
    required String question,
    required List<String> options,
    bool multipleChoice = false,
  });

  /// Ajoute ou retire une réaction emoji sur un message.
  /// Si [exclusive] est true, retire l'utilisateur de toutes les autres réactions.
  Future<void> toggleReaction({
    required String groupId,
    required String messageId,
    required String emoji,
    required String userId,
    required bool hasReacted,
    bool exclusive = true,
  });

  /// Enregistre le dernier message lu par l'utilisateur dans ce groupe.
  Future<void> markAsRead({
    required String groupId,
    required String userId,
    required String messageId,
    required DateTime messageTimestamp,
  });

  /// Stream du nombre de messages non lus pour l'utilisateur dans un groupe.
  Stream<int> watchUnreadCount({
    required String groupId,
    required String userId,
  });

  /// Marque le groupe comme lu à l'instant courant (ouverture du groupe).
  Future<void> markGroupAsRead({
    required String groupId,
    required String userId,
  });
}
