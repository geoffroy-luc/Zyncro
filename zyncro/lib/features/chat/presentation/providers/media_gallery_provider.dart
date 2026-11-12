import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';
import 'package:zyncro/features/chat/domain/live_window_pager.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';

class MediaGalleryState {
  final List<Message> messages;
  final bool hasMore;
  final bool loadingMore;

  const MediaGalleryState({
    required this.messages,
    this.hasMore = false,
    this.loadingMore = false,
  });
}

/// Galerie paginée (D9) : les [pageSize] médias les plus récents en temps
/// réel, puis les plus anciens chargés au défilement (même index composite
/// que l'aperçu du tableau de bord). Auparavant : tout l'historique d'un coup.
class MediaGalleryNotifier extends AsyncNotifier<MediaGalleryState> {
  static const pageSize = 60;

  late LiveWindowPager<Message> _pager;
  bool _loadingMore = false;

  @override
  Future<MediaGalleryState> build() async {
    final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
    _pager = LiveWindowPager(
      pageSize: pageSize,
      idOf: (m) => m.id,
      timeOf: (m) => m.timestamp,
    );
    _loadingMore = false;
    if (groupId == null) return const MediaGalleryState(messages: []);

    final first = Completer<void>();
    final sub = ref
        .read(messagesRepositoryProvider)
        .watchRecentMediaMessages(groupId, limit: pageSize)
        .listen(
          (msgs) {
            _pager.onLiveSnapshot(msgs);
            if (!first.isCompleted) {
              first.complete();
            } else {
              state = AsyncData(_snapshot());
            }
          },
          onError: (Object e, StackTrace st) {
            if (!first.isCompleted) {
              first.completeError(e, st);
            } else {
              state = AsyncError(e, st);
            }
          },
        );
    ref.onDispose(sub.cancel);

    await first.future;
    return _snapshot();
  }

  MediaGalleryState _snapshot() => MediaGalleryState(
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
    state = AsyncData(_snapshot());
    try {
      final page = await ref
          .read(messagesRepositoryProvider)
          .fetchMediaMessagesBefore(groupId, cursor, limit: pageSize);
      // Le groupe a pu changer pendant la requête : page jetée.
      if (identical(pager, _pager)) pager.addOlderPage(page);
    } finally {
      if (identical(pager, _pager)) {
        _loadingMore = false;
        state = AsyncData(_snapshot());
      }
    }
  }
}

final mediaGalleryProvider =
    AsyncNotifierProvider<MediaGalleryNotifier, MediaGalleryState>(
      MediaGalleryNotifier.new,
    );
