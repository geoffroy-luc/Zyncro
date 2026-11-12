part of 'chat_screen.dart';

/// Saisie, envoi, indicateur de frappe, défilement vers un message.
mixin _ChatComposer on _ChatScreenStateBase {
  GlobalKey _keyForMessage(String id) =>
      _messageKeys.putIfAbsent(id, GlobalKey.new);

  void _scrollToMessage(String? id, List<Message> messages) {
    if (id == null) return;
    final index = messages.indexWhere((m) => m.id == id);
    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.chatMessageIntrouvable),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final key = _keyForMessage(id);

    void highlight() {
      if (!mounted) return;
      setState(() => _highlightedMessageId = id);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
    }

    if (key.currentContext != null) {
      unawaited(
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.5,
        ).then((_) => highlight()),
      );
    } else {
      final estimated =
          _scrollController.position.maxScrollExtent *
          (index / messages.length);
      unawaited(
        _scrollController
            .animateTo(
              estimated,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            )
            .then((_) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (key.currentContext != null) {
                  unawaited(
                    Scrollable.ensureVisible(
                      key.currentContext!,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      alignment: 0.5,
                    ).then((_) => highlight()),
                  );
                } else {
                  highlight();
                }
              });
            }),
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      unawaited(ref.read(chatMessagesProvider.notifier).loadMore());
    }
  }

  void _onTextChanged() {
    setState(() {}); // toggle mic ↔ send button
    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (user == null || groupId == null || _controller.text.isEmpty) return;

    final repo = ref.read(messagesRepositoryProvider);
    _currentGroupId = groupId;
    _currentUserId = user.uid;
    _repo = repo;

    if (_typingThrottle.shouldSend()) {
      unawaited(
        repo.setTyping(
          groupId: groupId,
          userId: user.uid,
          userName:
              ref.read(currentMemberProvider).asData?.value?.displayName ??
              user.displayName ??
              user.email ??
              'Anonyme',
        ),
      );
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), _clearTyping);
  }

  void _clearTyping() {
    _typingThrottle.reset();
    final groupId = _currentGroupId;
    final userId = _currentUserId;
    final repo = _repo;
    if (groupId == null || userId == null || repo == null) return;
    unawaited(repo.clearTyping(groupId: groupId, userId: userId));
  }

  void _toggleTimestamp(String messageId) {
    setState(() {
      if (_visibleTimestamps.contains(messageId)) {
        _visibleTimestamps.remove(messageId);
      } else {
        _visibleTimestamps.add(messageId);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    // ── Edit mode ─────────────────────────────────────────────────────
    if (_editingMessage != null) {
      final message = _editingMessage!;
      final groupId = ref.read(selectedGroupIdProvider).asData?.value;
      if (groupId == null) return;

      setState(() {
        _editingMessage = null;
        _sending = true;
      });
      _controller.clear();

      try {
        if (text != message.content) {
          await ref
              .read(messagesRepositoryProvider)
              .editMessage(
                groupId: groupId,
                messageId: message.id,
                content: text,
              );
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatImpossibleDeModifierLeMessage),
          ),
        );
      } finally {
        if (mounted) setState(() => _sending = false);
      }
      return;
    }

    // ── Normal send ───────────────────────────────────────────────────
    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (user == null || groupId == null) return;

    _typingTimer?.cancel();
    _clearTyping();

    setState(() => _sending = true);
    _controller.clear();
    final reply = _replyingTo;
    setState(() => _replyingTo = null);

    try {
      await ref
          .read(messagesRepositoryProvider)
          .sendMessage(
            groupId: groupId,
            senderId: user.uid,
            senderName:
                ref.read(currentMemberProvider).asData?.value?.displayName ??
                user.displayName ??
                user.email ??
                'Anonyme',
            content: text,
            replyToId: reply?.id,
            replyToSenderName: reply?.senderName,
            replyToContent: reply?.content,
          );
      if (_scrollController.hasClients) {
        unawaited(
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
