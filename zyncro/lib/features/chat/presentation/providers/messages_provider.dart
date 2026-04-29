import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/messages_repository.dart';
import '../../domain/repositories/i_messages_repository.dart';
import '../../../../shared/models/message.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';

final messagesRepositoryProvider = Provider<IMessagesRepository>(
  (_) => MessagesRepository(),
);

final messagesProvider = StreamProvider<List<Message>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return Stream.value([]);
  return ref.watch(messagesRepositoryProvider).watchMessages(groupId);
});

/// True uniquement quand l'utilisateur est sur l'onglet Chat.
class ChatTabActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setActive(bool value) => state = value;
}

final isChatTabActiveProvider =
    NotifierProvider<ChatTabActiveNotifier, bool>(ChatTabActiveNotifier.new);

/// True quand l'app est au premier plan (foreground).
class AppInForegroundNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setForeground(bool value) => state = value;
}

final appInForegroundProvider =
    NotifierProvider<AppInForegroundNotifier, bool>(AppInForegroundNotifier.new);

/// Stream du lastReadAt de l'utilisateur courant pour un groupe donné.
final _memberLastReadAtProvider =
    StreamProvider.family<DateTime?, String>((ref, groupId) {
  final userId = ref.watch(authStateProvider).asData?.value?.uid;
  if (userId == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('members')
      .doc(userId)
      .snapshots()
      .map((snap) {
    final ts = snap.data()?['lastReadAt'] as Timestamp?;
    return ts?.toDate();
  });
});

/// Nombre de messages non lus pour l'utilisateur courant dans un groupe donné.
final unreadCountProvider = StreamProvider.family<int, String>((ref, groupId) {
  final lastReadAt =
      ref.watch(_memberLastReadAtProvider(groupId)).asData?.value;
  if (lastReadAt == null) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('messages')
      .where('timestamp', isGreaterThan: Timestamp.fromDate(lastReadAt))
      .snapshots()
      .map((snap) => snap.docs.length);
});

final typingProvider = StreamProvider<List<String>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  final currentUserId = ref.watch(authStateProvider).asData?.value?.uid;
  if (groupId == null || currentUserId == null) return Stream.value([]);
  return ref.watch(messagesRepositoryProvider).watchTyping(
        groupId: groupId,
        currentUserId: currentUserId,
      );
});
