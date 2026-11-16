part of 'chat_screen.dart';

/// Sections du build de l'écran : accusés de lecture, liste des messages,
/// aperçu de réponse, barre de saisie.
mixin _ChatScreenSections
    on
        _ChatScreenStateBase,
        _ChatComposer,
        _ChatMessageActions,
        _ChatRecording,
        _ChatActionMenus {
  /// Marque le dernier message comme lu (si [msgs] n'est pas vide).
  void _markLatestAsRead(List<Message>? msgs) {
    if (msgs == null || msgs.isEmpty) return;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    final userId = ref.read(authStateProvider).asData?.value?.uid;
    if (groupId == null || userId == null) return;
    unawaited(
      ref
          .read(messagesRepositoryProvider)
          .markAsRead(
            groupId: groupId,
            userId: userId,
            messageId: msgs.first.id,
            messageTimestamp: msgs.first.timestamp,
          ),
    );
  }

  /// BUG C14 corrigé : réponse, édition et recherche appartiennent au groupe
  /// affiché ; elles sont abandonnées quand on change de groupe (sinon
  /// `replyToId` d'un autre groupe, `editMessage` sur le mauvais `groupId`).
  void _listenGroupChange() {
    ref.listen(selectedGroupIdProvider.select((g) => g.asData?.value), (
      previous,
      next,
    ) {
      if (previous == next) return;
      setState(() {
        if (_editingMessage != null) _controller.clear();
        _editingMessage = null;
        _replyingTo = null;
        _search = '';
        _showSearch = false;
        _highlightedMessageId = null;
        _visibleTimestamps.clear();
      });
    });
  }

  /// Changement de compte (déconnexion) : l'indicateur de frappe de
  /// l'ancien compte n'est plus effaçable par le nouveau (refus des rules) ;
  /// on abandonne ce nettoyage, le document expire de lui-même (6 s).
  void _listenAccountChange() {
    ref.listen(authStateProvider.select((s) => s.value?.uid), (previous, next) {
      if (previous == null || previous == next) return;
      _typingTimer?.cancel();
      _currentUserId = null;
      _currentGroupId = null;
      _repo = null;
    });
  }

  /// À appeler depuis `build` (ref.listen).
  void _listenReadReceipts() {
    // Marque le dernier message comme lu quand un nouveau message arrive
    // (uniquement si le chat est actif ET l'app est au premier plan).
    ref.listen(chatMessagesProvider, (_, next) {
      if (!ref.read(isChatTabActiveProvider)) return;
      if (!ref.read(appInForegroundProvider)) return;
      final msgs = next.asData?.value.messages;
      _markLatestAsRead(msgs);
    });

    // Marque le dernier message comme lu dès qu'on arrive sur l'onglet chat
    // (navigation depuis la nav bar ou ouverture via notification).
    ref.listen(isChatTabActiveProvider, (_, isActive) {
      if (!isActive) return;
      final msgs = ref.read(chatMessagesProvider).asData?.value.messages;
      _markLatestAsRead(msgs);
    });

    // Marque le dernier message comme lu quand l'app revient au premier plan
    // avec le chat déjà actif (isChatTabActive ne change pas dans ce cas).
    ref.listen(appInForegroundProvider, (_, inForeground) {
      if (!inForeground) return;
      if (!ref.read(isChatTabActiveProvider)) return;
      final msgs = ref.read(chatMessagesProvider).asData?.value.messages;
      _markLatestAsRead(msgs);
    });
  }

  Widget _buildMessageList(
    ChatMessagesState chatState,
    String currentUid,
    List<GroupMember> members,
    String? bgType,
  ) {
    // Réglage de l'appareil : masquer l'activité de l'espace (messages
    // système) dans le chat.
    final activityVisible = ref.watch(chatActivityVisibleProvider);
    final allMessages = activityVisible
        ? chatState.messages
        : chatState.messages
              .where((m) => m.type != MessageType.system)
              .toList();
    final messages = _search.isEmpty
        ? allMessages
        : allMessages.where((m) {
            final q = _search.toLowerCase();
            final textContent = m.type == MessageType.text
                ? m.content.toLowerCase()
                : '';
            return textContent.contains(q) ||
                (m.senderName?.toLowerCase().contains(q) ?? false);
          }).toList();
    if (messages.isEmpty) {
      return Center(
        child: Text(
          // BUG C12 corrigé : message dédié quand c'est la recherche qui
          // ne trouve rien.
          _search.isEmpty
              ? context.l10n.chatAucunMessageSoyezLePremier
              : context.l10n.chatAucunResultat,
          style: TextStyle(color: context.colors.textSecondary),
        ),
      );
    }

    // messageId → membres (hors soi-même) qui ont lu jusqu'à ce message
    final seenByMessage = <String, List<GroupMember>>{};
    for (final member in members) {
      if (member.uid == currentUid) continue;
      final rid = member.lastReadMessageId;
      if (rid == null) continue;
      seenByMessage.putIfAbsent(rid, () => []).add(member);
    }

    // Activités consécutives (notes, événements, dépenses, arrivées)
    // regroupées en un bloc repliable.
    final items = groupActivity(messages);

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: items.length + (chatState.loadingMore ? 1 : 0),
      itemBuilder: (_, j) {
        if (j == items.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }

        final item = items[j];
        if (item is ActivityGroupItem) {
          return _buildActivityGroup(item, messages, seenByMessage, bgType);
        }
        final i = (item as MessageItem).index;
        final msg = messages[i];
        final isMe = msg.senderId == currentUid;

        final newerMsg = i > 0 ? messages[i - 1] : null;
        final olderMsg = i < messages.length - 1 ? messages[i + 1] : null;

        final isFirstInGroup = newerMsg == null || !_isSameGroup(msg, newerMsg);
        final isLastInGroup = olderMsg == null || !_isSameGroup(olderMsg, msg);

        final isPoll = msg.type == MessageType.poll;
        final seenBy = seenByMessage[msg.id] ?? [];

        return Column(
          key: _keyForMessage(msg.id),
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: EdgeInsets.only(
                bottom: seenBy.isEmpty && isFirstInGroup ? 10 : 2,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: _highlightedMessageId == msg.id
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.13)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwipeToReply(
                  isMe: isMe,
                  onReply: msg.type != MessageType.system && !isPoll
                      ? () => setState(() => _replyingTo = msg)
                      : null,
                  child: MessageBubble(
                    message: msg,
                    isMe: isMe,
                    currentUserId: currentUid,
                    showTimestamp: _visibleTimestamps.contains(msg.id),
                    showAvatar: !isMe && isFirstInGroup,
                    showSenderName: !isMe && isLastInGroup,
                    isFirstInGroup: isFirstInGroup,
                    isLastInGroup: isLastInGroup,
                    member: members
                        .where((m) => m.uid == msg.senderId)
                        .firstOrNull,
                    members: members,
                    resolvedReplyContent: msg.replyToId != null
                        ? messages
                              .where((m) => m.id == msg.replyToId)
                              .firstOrNull
                              ?.content
                        : null,
                    onTap: msg.type != MessageType.system && !isPoll
                        ? () => _toggleTimestamp(msg.id)
                        : null,
                    onDoubleTap: msg.type != MessageType.system && !isPoll
                        ? () => _onDoubleTap(msg)
                        : null,
                    onLongPress: msg.type != MessageType.system
                        ? () => _onMessageLongPress(msg, isMe)
                        : null,
                    onVote: isPoll ? (idx) => _votePoll(msg, idx) : null,
                    hasCustomBackground: bgType != null && bgType != 'none',
                    onReplyPreviewTap: msg.replyToId != null
                        ? () => _scrollToMessage(msg.replyToId, messages)
                        : null,
                  ),
                ),
              ),
            ),
            if (seenBy.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  bottom: isFirstInGroup ? 10 : 2,
                  right: 4,
                ),
                child: SeenByRow(members: seenBy),
              ),
          ],
        );
      },
    );
  }

  Widget _buildReplyPreview(Message replyingTo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          replyingTo.senderName ?? '',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          replyLabel(context, replyingTo.content),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 24, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: _isRecording
          // ── Recording mode ────────────────────────────────────
          ? RecordingBar(
              elapsed: _fmtDuration(_recordingDuration),
              onCancel: _cancelRecording,
              onSend: _stopAndSendAudio,
            )
          // ── Normal mode ───────────────────────────────────────
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _inputIconsCluster(context),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.background,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _inputFocusNode,
                      decoration: InputDecoration(
                        hintText: context.l10n.chatEcrireUnMessage,
                        hintStyle: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        filled: false,
                        isDense: true,
                      ),
                      maxLines: 4,
                      minLines: 1,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                      ),
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Mic quand champ vide, Send quand du texte
                if (_controller.text.isEmpty && !_sending)
                  GradientCircleButton(
                    onTap: _startRecording,
                    child: _isUploading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.mic, color: Colors.white, size: 22),
                  )
                else
                  GradientCircleButton(
                    onTap: _send,
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
              ],
            ),
    );
  }

  Widget _buildActivityGroup(
    ActivityGroupItem group,
    List<Message> messages,
    Map<String, List<GroupMember>> seenByMessage,
    String? bgType,
  ) {
    final activities = [for (final i in group.indices) messages[i]];
    final key = activities.first.id;
    // Lu jusqu'à l'une de ces activités : affiché sous le bloc.
    final seenBy = {
      for (final m in activities)
        for (final member in seenByMessage[m.id] ?? <GroupMember>[])
          member.uid: member,
    }.values.toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ActivityGroupTile(
            activities: activities,
            expanded: _expandedActivity.contains(key),
            hasCustomBackground: bgType != null && bgType != 'none',
            onToggle: () => setState(() {
              if (!_expandedActivity.remove(key)) _expandedActivity.add(key);
            }),
          ),
          if (seenBy.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: SeenByRow(members: seenBy),
            ),
        ],
      ),
    );
  }
}
