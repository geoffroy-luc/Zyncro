import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/core/firebase/firebase_providers.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/chat/data/repositories/firestore_messages_repository.dart';
import 'package:zyncro/features/chat/data/services/link_preview_service.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';
import 'package:zyncro/features/chat/domain/live_window_pager.dart';
import 'package:zyncro/features/chat/domain/repositories/messages_repository.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>(
  (ref) => FirestoreMessagesRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  ),
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

/// Fenêtre live des 50 derniers messages + pages plus anciennes.
///
/// BUG C1 corrigé : un message poussé hors de la fenêtre live par un nouvel
/// arrivant reste affiché (LiveWindowPager). BUG C3 corrigé : « plus
/// d'historique » est recalculé à chaque instantané au lieu d'être figé à
/// false dès qu'une fenêtre incomplète a été vue.
class ChatMessagesNotifier extends AsyncNotifier<ChatMessagesState> {
  static const pageSize = 50;

  late LiveWindowPager<Message> _pager;
  bool _loadingMore = false;

  @override
  Future<ChatMessagesState> build() async {
    final groupId = ref.watch(selectedGroupIdProvider).asData?.value;

    _pager = LiveWindowPager(
      pageSize: pageSize,
      idOf: (m) => m.id,
      timeOf: (m) => m.timestamp,
    );
    _loadingMore = false;

    if (groupId == null) {
      return const ChatMessagesState(messages: [], hasMore: false);
    }

    final repo = ref.read(messagesRepositoryProvider);
    final completer = Completer<void>();

    final sub = repo
        .watchMessages(groupId)
        .listen(
          (msgs) {
            _pager.onLiveSnapshot(msgs);
            if (!completer.isCompleted) {
              completer.complete();
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

  ChatMessagesState _buildState() => ChatMessagesState(
    messages: _pager.items,
    hasMore: _pager.hasMore,
    loadingMore: _loadingMore,
  );

  Future<void> loadMore() async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    final cursor = _pager.cursor;
    if (_loadingMore || !_pager.hasMore || groupId == null || cursor == null) {
      return;
    }
    final pager = _pager;
    _loadingMore = true;
    state = AsyncData(_buildState());
    try {
      final batch = await ref
          .read(messagesRepositoryProvider)
          .fetchMessagesBefore(groupId, cursor);
      // Le groupe a pu changer pendant la requête : page jetée.
      if (identical(pager, _pager)) pager.addOlderPage(batch);
    } finally {
      if (identical(pager, _pager)) {
        _loadingMore = false;
        state = AsyncData(_buildState());
      }
    }
  }
}

final chatMessagesProvider =
    AsyncNotifierProvider<ChatMessagesNotifier, ChatMessagesState>(
      ChatMessagesNotifier.new,
    );

/// Les 6 derniers médias du groupe (aperçu du tableau de bord) : requête
/// bornée côté serveur au lieu de tout l'historique.
final recentMediaMessagesProvider = StreamProvider<List<Message>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return Stream.value([]);
  return ref
      .watch(messagesRepositoryProvider)
      .watchRecentMediaMessages(groupId, limit: 6);
});

/// True uniquement quand l'utilisateur est sur l'onglet Chat.
class ChatTabActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setActive(bool value) => state = value;
}

final isChatTabActiveProvider = NotifierProvider<ChatTabActiveNotifier, bool>(
  ChatTabActiveNotifier.new,
);

/// True quand l'app est au premier plan (foreground).
class AppInForegroundNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setForeground(bool value) => state = value;
}

final appInForegroundProvider = NotifierProvider<AppInForegroundNotifier, bool>(
  AppInForegroundNotifier.new,
);

/// Stream du lastReadAt de l'utilisateur courant pour un groupe donné.
final _memberLastReadAtProvider = StreamProvider.family<DateTime?, String>((
  ref,
  groupId,
) {
  final userId = ref.watch(authStateProvider).asData?.value?.uid;
  if (userId == null) return Stream.value(null);
  return ref
      .watch(messagesRepositoryProvider)
      .watchLastReadAt(groupId: groupId, userId: userId);
});

/// Nombre de messages non lus pour l'utilisateur courant dans un groupe donné.
final unreadCountProvider = StreamProvider.family<int, String>((ref, groupId) {
  final lastReadAt = ref
      .watch(_memberLastReadAtProvider(groupId))
      .asData
      ?.value;
  if (lastReadAt == null) return Stream.value(0);
  return ref
      .watch(messagesRepositoryProvider)
      .watchCountSince(groupId: groupId, since: lastReadAt);
});

final typingProvider = StreamProvider<List<String>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  final currentUserId = ref.watch(authStateProvider).asData?.value?.uid;
  if (groupId == null || currentUserId == null) return Stream.value([]);
  return ref
      .watch(messagesRepositoryProvider)
      .watchTyping(groupId: groupId, currentUserId: currentUserId);
});

/// Aperçus de liens (cache mémoire partagé par toutes les bulles).
final linkPreviewServiceProvider = Provider<LinkPreviewService>(
  (_) => LinkPreviewService(),
);
