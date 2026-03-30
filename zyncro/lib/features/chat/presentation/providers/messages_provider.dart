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

final typingProvider = StreamProvider<List<String>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  final currentUserId = ref.watch(authStateProvider).asData?.value?.uid;
  if (groupId == null || currentUserId == null) return Stream.value([]);
  return ref.watch(messagesRepositoryProvider).watchTyping(
        groupId: groupId,
        currentUserId: currentUserId,
      );
});
