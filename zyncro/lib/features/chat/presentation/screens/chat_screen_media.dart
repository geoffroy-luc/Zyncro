part of 'chat_screen.dart';

/// Envoi de photos / vidéos (galerie, caméra), compression.
mixin _ChatMediaSending on _ChatScreenStateBase {
  @override
  Future<void> _pickFromGallery() async {
    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (user == null || groupId == null) return;
    final senderName =
        ref.read(currentMemberProvider).asData?.value?.displayName ??
        user.displayName ??
        user.email ??
        'Anonyme';
    final reply = _replyingTo;

    final picked = await Navigator.of(context, rootNavigator: true)
        .push<MediaPickerResult>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const MediaPickerScreen(),
          ),
        );
    if (picked == null || picked.isEmpty || !mounted) return;

    setState(() {
      _isUploadingMedia = true;
      _replyingTo = null;
    });
    try {
      final compressed = await ref
          .read(mediaPreparerProvider)
          .prepareBatch(picked, filePrefix: 'compressed');

      if (picked.length == 1) {
        await ref
            .read(messagesRepositoryProvider)
            .sendMedia(
              groupId: groupId,
              senderId: user.uid,
              senderName: senderName,
              filePath: compressed.first.filePath,
              mimeType: compressed.first.mimeType,
              replyToId: reply?.id,
              replyToSenderName: reply?.senderName,
              replyToContent: reply?.content,
            );
      } else {
        await ref
            .read(messagesRepositoryProvider)
            .sendMultipleMedia(
              groupId: groupId,
              senderId: user.uid,
              senderName: senderName,
              medias: compressed,
              replyToId: reply?.id,
              replyToSenderName: reply?.senderName,
              replyToContent: reply?.content,
            );
      }
      if (_scrollController.hasClients) {
        unawaited(
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatErreurEnvoiMedia(e))),
      );
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  @override
  Future<void> _captureFromCamera({required bool video}) async {
    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (user == null || groupId == null) return;
    final senderName =
        ref.read(currentMemberProvider).asData?.value?.displayName ??
        user.displayName ??
        user.email ??
        'Anonyme';
    final reply = _replyingTo;

    final picker = ref.read(imagePickerServiceProvider);
    String? filePath;
    String mimeType;
    if (video) {
      filePath = await picker.pickVideo(source: MediaSource.camera);
      if (filePath == null || !mounted) return;
      mimeType = 'video/mp4';
    } else {
      filePath = await picker.pickImage(
        source: MediaSource.camera,
        imageQuality: 85,
      );
      if (filePath == null || !mounted) return;
      mimeType = 'image/jpeg';
    }

    setState(() {
      _isUploadingMedia = true;
      _replyingTo = null;
    });
    try {
      final prepared = await ref
          .read(mediaPreparerProvider)
          .prepareSingle(filePath, mimeType);
      final uploadPath = prepared.filePath;
      mimeType = prepared.mimeType;
      await ref
          .read(messagesRepositoryProvider)
          .sendMedia(
            groupId: groupId,
            senderId: user.uid,
            senderName: senderName,
            filePath: uploadPath,
            mimeType: mimeType,
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatErreurEnvoiMedia(e))),
      );
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }
}
