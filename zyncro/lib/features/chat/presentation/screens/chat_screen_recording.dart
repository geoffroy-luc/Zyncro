part of 'chat_screen.dart';

/// Enregistrement et envoi des messages vocaux.
mixin _ChatRecording on _ChatScreenStateBase {
  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatPermissionMicrophoneRefusee)),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });
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
