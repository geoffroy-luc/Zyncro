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
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final compressed = await Future.wait(
        picked.asMap().entries.map((e) async {
          final index = e.key;
          final media = e.value;
          if (media.mimeType.startsWith('image/')) {
            final targetPath = '${dir.path}/compressed_${ts}_$index.jpg';
            final result = await FlutterImageCompress.compressAndGetFile(
              media.path,
              targetPath,
              quality: 85,
              minHeight: 1920,
            );
            return (
              filePath: result?.path ?? media.path,
              mimeType: 'image/jpeg',
            );
          }
          return (filePath: media.path, mimeType: media.mimeType);
        }),
      );

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur envoi média : $e')));
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

    final picker = ImagePicker();
    XFile? file;
    String mimeType;
    if (video) {
      file = await picker.pickVideo(source: ImageSource.camera);
      if (file == null || !mounted) return;
      mimeType = 'video/mp4';
    } else {
      file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      mimeType = 'image/jpeg';
    }

    setState(() {
      _isUploadingMedia = true;
      _replyingTo = null;
    });
    try {
      String uploadPath = file.path;
      if (mimeType.startsWith('image/')) {
        final dir = await getTemporaryDirectory();
        final targetPath =
            '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final result = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          quality: 85,
          minHeight: 1920,
        );
        if (result != null) {
          uploadPath = result.path;
          mimeType = 'image/jpeg';
        }
      }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur envoi média : $e')));
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }
}
