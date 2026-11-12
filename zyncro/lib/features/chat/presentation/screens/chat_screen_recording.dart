part of 'chat_screen.dart';

/// Enregistrement et envoi des messages vocaux.
mixin _ChatRecording on _ChatScreenStateBase {
  String _fmtDuration(Duration d) => formatDuration(d);

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatPermissionMicrophoneRefusee)),
        );
      }
      return;
    }
    final dir = await ref.read(temporaryDirectoryProvider)();
    final path = '$dir/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(path);
    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });
    _recordingTimer?.cancel(); // BUG C15 corrigé : jamais deux timers.
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingDuration += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await _recorder.cancel();
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });
  }

  Future<void> _stopAndSendAudio() async {
    _recordingTimer?.cancel();
    final path = await _recorder.stop();
    final duration = _recordingDuration;
    setState(() {
      _isRecording = false;
      _isUploading = true;
      _recordingDuration = Duration.zero;
    });

    if (path == null) {
      if (mounted) setState(() => _isUploading = false);
      return;
    }

    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (user == null || groupId == null) {
      if (mounted) setState(() => _isUploading = false);
      return;
    }

    // BUG C10 corrigé : la réponse en cours accompagne le vocal.
    final reply = _replyingTo;
    setState(() => _replyingTo = null);
    try {
      await ref
          .read(messagesRepositoryProvider)
          .sendAudio(
            groupId: groupId,
            senderId: user.uid,
            senderName:
                ref.read(currentMemberProvider).asData?.value?.displayName ??
                user.displayName ??
                user.email ??
                'Anonyme',
            filePath: path,
            durationSeconds: duration.inSeconds,
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
      ).showSnackBar(SnackBar(content: Text(context.l10n.chatAudioError(e))));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
