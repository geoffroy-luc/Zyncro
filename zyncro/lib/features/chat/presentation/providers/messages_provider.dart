import 'dart:async';

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

// ── Pagination state ─────────────────────────────────────────────────────────

class ChatMessagesState {
  final List<Message> messages;
  final bool hasMore;
  final bool loadingMore;

  const ChatMessagesState({
    required this.messages,
    this.hasMore = true,
    this.loadingMore = false,
  });

  ChatMessagesState copyWith({
    List<Message>? messages,
    bool? hasMore,
    bool? loadingMore,
  }) => ChatMessagesState(
    messages: messages ?? this.messages,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

class ChatMessagesNotifier extends AsyncNotifier<ChatMessagesState> {
  List<Message> _live = [];
  List<Message> _older = [];
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  Future<ChatMessagesState> build() async {
    final groupId = ref.watch(selectedGroupIdProvider).asData?.value;

    _live = [];
    _older = [];
    _hasMore = true;
    _loadingMore = false;

    if (groupId == null) {
      return const ChatMessagesState(messages: [], hasMore: false);
    }

    final repo = ref.read(messagesRepositoryProvider);
    final completer = Completer<List<Message>>();

    final sub = repo.watchMessages(groupId).listen(
      (msgs) {
        _live = msgs;
        if (msgs.length < 50) _hasMore = false;
        if (!completer.isCompleted) {
          completer.complete(msgs);
        } else {
          state = AsyncData(_buildState());
        }
      },
      onError: (Object e, StackTrace st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        } else {
          state = AsyncError(e, st);
        }
      },
    );

    ref.onDispose(sub.cancel);

    await completer.future;
    return _buildState();
  }

  ChatMessagesState _buildState() {
    final liveIds = _live.map((m) => m.id).toSet();
    return ChatMessagesState(
      messages: [
        ..._live,
        ..._older.where((m) => !liveIds.contains(m.id)),
      ],
      hasMore: _hasMore,
      loadingMore: _loadingMore,
    );
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final current = state.value;
    if (current == null || current.messages.isEmpty) return;

    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;

    _loadingMore = true;
    state = AsyncData(current.copyWith(loadingMore: true));

    try {
      final oldest = current.messages.last.timestamp;
      final batch = await ref
          .read(messagesRepositoryProvider)
          .fetchMessagesBefore(groupId, oldest);
      _older = [..._older, ...batch];
      if (batch.length < 50) _hasMore = false;
    } finally {
      _loadingMore = false;
      state = AsyncData(_buildState());
    }
  }
}

final chatMessagesProvider =
    AsyncNotifierProvider<ChatMessagesNotifier, ChatMessagesState>(
  ChatMessagesNotifier.new,
);

final mediaMessagesProvider = StreamProvider<List<Message>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return Stream.value([]);
  return ref.watch(messagesRepositoryProvider).watchMediaMessages(groupId);
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
