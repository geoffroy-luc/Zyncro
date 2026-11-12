part of 'chat_screen.dart';

/// Actions sur un message : réactions, menu appui long, édition, suppression, sondages, téléchargement.
mixin _ChatMessageActions on _ChatScreenStateBase {
  Future<void> _onDoubleTap(Message message) async {
    final currentUser = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (currentUser == null || groupId == null) return;

    const emoji = '❤️';
    final hasReacted =
        message.reactions[emoji]?.contains(currentUser.uid) == true;
    await ref
        .read(messagesRepositoryProvider)
        .toggleReaction(
          groupId: groupId,
          messageId: message.id,
          emoji: emoji,
          userId: currentUser.uid,
          hasReacted: hasReacted,
        );
  }

  Future<void> _onMessageLongPress(Message message, bool isMe) async {
    final currentUser = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (currentUser == null || groupId == null) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BUG C8 corrigé : pas de réaction emoji sur un sondage (comptée
            // comme un vote, invisible sur la carte).
            if (message.type != MessageType.poll)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _quickEmojis.map((emoji) {
                    final hasReacted =
                        message.reactions[emoji]?.contains(currentUser.uid) ==
                        true;
                    return GestureDetector(
                      onTap: () => Navigator.of(ctx).pop('react:$emoji'),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: hasReacted
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.15)
                              : context.colors.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: hasReacted
                                ? Theme.of(context).colorScheme.primary
                                : context.colors.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const Divider(height: 1),
            // BUG C9 corrigé : pas de « Répondre » sur un sondage (la carte
            // n'affiche pas de citation, le balayage est déjà désactivé).
            if (message.type != MessageType.poll)
              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: Text(context.l10n.chatRepondre),
                onTap: () => Navigator.of(ctx).pop('reply'),
              ),
            if (message.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.content_copy_outlined),
                title: Text(context.l10n.chatCopier),
                onTap: () => Navigator.of(ctx).pop('copy'),
              ),
            // BUG C5 corrigé : seul un texte se modifie (le contenu d'un
            // média / album est du JSON, l'éditer cassait le média).
            if (isMe && message.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.l10n.chatModifier),
                onTap: () => Navigator.of(ctx).pop('edit'),
              ),
            if (isMe && message.type == MessageType.poll)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.l10n.chatModifierLeSondage),
                onTap: () => Navigator.of(ctx).pop('edit_poll'),
              ),
            if (message.type == MessageType.image ||
                message.type == MessageType.file)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(context.l10n.chatTelecharger),
                onTap: () => Navigator.of(ctx).pop('download'),
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  context.l10n.chatSupprimer,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.content));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatMessageCopie),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (action == 'reply') {
      setState(() => _replyingTo = message);
      return;
    }
    if (action.startsWith('react:')) {
      final emoji = action.substring(6);
      final hasReacted =
          message.reactions[emoji]?.contains(currentUser.uid) == true;
      await ref
          .read(messagesRepositoryProvider)
          .toggleReaction(
            groupId: groupId,
            messageId: message.id,
            emoji: emoji,
            userId: currentUser.uid,
            hasReacted: hasReacted,
          );
      return;
    }
    if (action == 'edit') {
      _editMessage(message);
      return;
    }
    if (action == 'edit_poll') {
      await _editPoll(message);
      return;
    }
    if (action == 'download') {
      await _downloadMedia(message);
      return;
    }
    if (action == 'delete') {
      await _deleteMessage(message);
    }
  }

  Future<void> _downloadMedia(Message message) async {
    try {
      final data = jsonDecode(message.content) as Map<String, dynamic>;
      // BUG C6 corrigé : un album enregistre tous ses médias.
      if (data['medias'] is List) {
        await _downloadAlbum(
          (data['medias'] as List).cast<Map<String, dynamic>>(),
        );
        return;
      }
      final url = data['url'] as String? ?? '';
      if (url.isEmpty) return;
      if (message.type == MessageType.image) {
        await MediaDownloader.downloadImage(context, url);
      } else if (message.type == MessageType.file) {
        await MediaDownloader.downloadVideo(context, url);
      }
    } catch (_) {}
  }

  Future<void> _downloadAlbum(List<Map<String, dynamic>> medias) async {
    final saver = ref.read(gallerySaverProvider);
    try {
      var saved = 0;
      for (final m in medias) {
        final url = m['url'] as String? ?? '';
        if (url.isEmpty) continue;
        if ((m['mimeType'] as String? ?? '').startsWith('video/')) {
          await saver.saveVideoFromUrl(url);
        } else {
          await saver.saveImageFromUrl(url);
        }
        saved++;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatMediasEnregistres(saved))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatErreurTelechargement(e))),
      );
    }
  }

  void _editMessage(Message message) {
    setState(() {
      _editingMessage = message;
      _replyingTo = null;
      _controller.text = message.content;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: message.content.length),
      );
    });
    _inputFocusNode.requestFocus();
  }

  Future<void> _editPoll(Message message) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.content) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final question = data['question'] as String? ?? '';
    final options = List<String>.from(data['options'] as List? ?? []);
    final multipleChoice = data['multipleChoice'] as bool? ?? false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => EditPollDialog(
        question: question,
        options: options,
        multipleChoice: multipleChoice,
      ),
    );
    if (result == null || !mounted) return;

    try {
      await ref
          .read(messagesRepositoryProvider)
          .editPoll(
            groupId: groupId,
            messageId: message.id,
            question: result['question'] as String,
            options: List<String>.from(result['options'] as List),
            multipleChoice: result['multipleChoice'] as bool? ?? false,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatImpossibleDeModifierLeSondage)),
      );
    }
  }

  Future<void> _deleteMessage(Message message) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.chatSupprimerLeMessage),
        content: Text(context.l10n.chatCeMessageSeraSupprimeDefinitivement),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.chatAnnuler),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.l10n.chatSupprimer),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(messagesRepositoryProvider)
          .deleteMessage(groupId: groupId, messageId: message.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.chatImpossibleDeSupprimerLeMessage),
        ),
      );
    }
  }

  Future<void> _votePoll(Message message, int optionIndex) async {
    final currentUser = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (currentUser == null || groupId == null) return;

    final key = optionIndex.toString();
    final hasVoted = message.reactions[key]?.contains(currentUser.uid) == true;

    bool multipleChoice = false;
    try {
      final data = jsonDecode(message.content) as Map<String, dynamic>;
      multipleChoice = data['multipleChoice'] as bool? ?? false;
    } catch (_) {}

    await ref
        .read(messagesRepositoryProvider)
        .toggleReaction(
          groupId: groupId,
          messageId: message.id,
          emoji: key,
          userId: currentUser.uid,
          hasReacted: hasVoted,
          exclusive: !multipleChoice,
        );
  }

  @override
  Future<void> _showCreatePoll() async {
    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (user == null || groupId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const CreatePollDialog(),
    );
    if (result == null || !mounted) return;

    // BUG C10 corrigé : la réponse en cours accompagne le sondage.
    final reply = _replyingTo;
    setState(() => _replyingTo = null);
    await ref
        .read(messagesRepositoryProvider)
        .sendPoll(
          groupId: groupId,
          senderId: user.uid,
          senderName:
              ref.read(currentMemberProvider).asData?.value?.displayName ??
              user.displayName ??
              user.email ??
              'Anonyme',
          question: result['question'] as String,
          options: List<String>.from(result['options'] as List),
          multipleChoice: result['multipleChoice'] as bool? ?? false,
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
  }
}
