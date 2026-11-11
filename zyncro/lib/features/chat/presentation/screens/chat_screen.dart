import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';
import 'package:zyncro/features/chat/domain/repositories/messages_repository.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/chat/presentation/screens/media_picker_screen.dart';
import 'package:zyncro/features/chat/presentation/screens/media_viewer_screen.dart';
import 'package:zyncro/features/chat/presentation/widgets/create_poll_dialog.dart';
import 'package:zyncro/features/chat/presentation/widgets/edit_poll_dialog.dart';
import 'package:zyncro/features/chat/presentation/widgets/message_bubble.dart';
import 'package:zyncro/features/chat/presentation/widgets/seen_by_row.dart';
import 'package:zyncro/features/chat/presentation/widgets/swipe_to_reply.dart';
import 'package:zyncro/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:zyncro/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:zyncro/features/groups/domain/entities/group_member.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();
  bool _sending = false;
  Timer? _typingTimer;
  final Set<String> _visibleTimestamps = {};
  Message? _replyingTo;
  Message? _editingMessage;
  String _search = '';
  bool _showSearch = false;
  bool _showQuickActions = false;
  bool _showCameraActions = false;
  final LayerLink _cameraButtonLink = LayerLink();
  final LayerLink _plusButtonLink = LayerLink();

  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  GlobalKey _keyForMessage(String id) =>
      _messageKeys.putIfAbsent(id, GlobalKey.new);

  void _scrollToMessage(String? id, List<Message> messages) {
    if (id == null) return;
    final index = messages.indexWhere((m) => m.id == id);
    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message introuvable'),
          duration: Duration(seconds: 2),
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

  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isUploading = false;
  bool _isUploadingMedia = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // Sauvegardés pour pouvoir les utiliser dans dispose() sans ref
  String? _currentGroupId;
  String? _currentUserId;
  MessagesRepository? _repo;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
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

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), _clearTyping);
  }

  void _clearTyping() {
    final groupId = _currentGroupId;
    final userId = _currentUserId;
    final repo = _repo;
    if (groupId == null || userId == null || repo == null) return;
    unawaited(repo.clearTyping(groupId: groupId, userId: userId));
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    unawaited(_recorder.dispose());
    _clearTyping();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _inputFocusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
          const SnackBar(content: Text('Impossible de modifier le message.')),
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

  static const _quickEmojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];

  static bool _isSameGroup(Message older, Message newer) {
    if (older.senderId == null || older.senderId != newer.senderId) {
      return false;
    }
    if (older.type == MessageType.system || newer.type == MessageType.system) {
      return false;
    }
    if (older.type == MessageType.poll || newer.type == MessageType.poll) {
      return false;
    }
    return newer.timestamp.difference(older.timestamp).inMinutes < 3;
  }

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Répondre'),
              onTap: () => Navigator.of(ctx).pop('reply'),
            ),
            if (message.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.content_copy_outlined),
                title: const Text('Copier'),
                onTap: () => Navigator.of(ctx).pop('copy'),
              ),
            if (isMe &&
                message.type != MessageType.poll &&
                message.type != MessageType.audio)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier'),
                onTap: () => Navigator.of(ctx).pop('edit'),
              ),
            if (isMe && message.type == MessageType.poll)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier le sondage'),
                onTap: () => Navigator.of(ctx).pop('edit_poll'),
              ),
            if (message.type == MessageType.image ||
                message.type == MessageType.file)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Télécharger'),
                onTap: () => Navigator.of(ctx).pop('download'),
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
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
          const SnackBar(
            content: Text('Message copié'),
            duration: Duration(seconds: 2),
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
      final url = data['url'] as String? ?? '';
      if (url.isEmpty) return;
      if (message.type == MessageType.image) {
        await MediaDownloader.downloadImage(context, url);
      } else if (message.type == MessageType.file) {
        await MediaDownloader.downloadVideo(context, url);
      }
    } catch (_) {}
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
        const SnackBar(content: Text('Impossible de modifier le sondage.')),
      );
    }
  }

  Future<void> _deleteMessage(Message message) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le message'),
        content: const Text('Ce message sera supprimé définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
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
        const SnackBar(content: Text('Impossible de supprimer le message.')),
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

  Future<void> _showCreatePoll() async {
    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (user == null || groupId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const CreatePollDialog(),
    );
    if (result == null || !mounted) return;

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

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission microphone refusée.')),
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
      ).showSnackBar(SnackBar(content: Text('Audio error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

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

  Widget _plusIconButton(BuildContext context) {
    return CompositedTransformTarget(
      link: _plusButtonLink,
      child: GestureDetector(
        onTap: () => setState(() {
          _showQuickActions = !_showQuickActions;
          if (_showQuickActions) _showCameraActions = false;
        }),
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(right: 8, bottom: 2),
          decoration: BoxDecoration(
            color: _showQuickActions
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : context.colors.background,
            shape: BoxShape.circle,
            border: Border.all(
              color: _showQuickActions
                  ? Theme.of(context).colorScheme.primary
                  : context.colors.border,
            ),
          ),
          child: AnimatedRotation(
            turns: _showQuickActions ? 0.125 : 0,
            duration: const Duration(milliseconds: 150),
            child: Icon(
              Icons.add,
              color: _showQuickActions
                  ? Theme.of(context).colorScheme.primary
                  : context.colors.textSecondary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // Menu radial : les options se déploient en quart de cercle au-dessus
  // et à droite du bouton "+" (0° = tout droit, 90° = complètement à droite),
  // ancré exactement sur le bouton via _plusButtonLink.
  Widget _quickActionsPopup(BuildContext context) {
    const radius = 62.0;
    const buttonSize = 40.0;
    // La popup est centrée (via CompositedTransformFollower.followerAnchor)
    // sur le bouton "+" ; boxCenter sert d'origine pour repositionner les
    // options qui, sinon, débordent d'une boîte 0x0 et ne reçoivent aucun tap
    // (le hit-test d'un Stack est borné par sa propre taille, même avec
    // clipBehavior: Clip.none qui ne fait que dessiner au-delà).
    const boxSize = 200.0;
    const boxCenter = boxSize / 2;

    Widget option({
      required IconData icon,
      required bool active,
      required VoidCallback onTap,
      required double angleDeg,
      required int index,
    }) {
      final angle = angleDeg * math.pi / 180;
      final dx = radius * math.sin(angle);
      final dy = -radius * math.cos(angle);
      return Positioned(
        left: boxCenter + dx - buttonSize / 2,
        top: boxCenter + dy - buttonSize / 2,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 200 + index * 40),
          curve: Curves.easeOutBack,
          builder: (_, value, child) =>
              Transform.scale(scale: value, child: child),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : context.colors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : context.colors.textSecondary,
                size: 18,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          option(
            icon: Icons.search,
            active: _showSearch,
            angleDeg: 15,
            index: 0,
            onTap: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) _search = '';
              _showQuickActions = false;
            }),
          ),
          option(
            icon: Icons.poll_outlined,
            active: false,
            angleDeg: 75,
            index: 1,
            onTap: () {
              setState(() => _showQuickActions = false);
              unawaited(_showCreatePoll());
            },
          ),
        ],
      ),
    );
  }

  Widget _cameraIconButton(BuildContext context) {
    return CompositedTransformTarget(
      link: _cameraButtonLink,
      child: GestureDetector(
        onTap: _isUploadingMedia
            ? null
            : () => setState(() {
                _showCameraActions = !_showCameraActions;
                if (_showCameraActions) _showQuickActions = false;
              }),
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(right: 8, bottom: 2),
          decoration: BoxDecoration(
            color: _showCameraActions
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : context.colors.background,
            shape: BoxShape.circle,
            border: Border.all(
              color: _showCameraActions
                  ? Theme.of(context).colorScheme.primary
                  : context.colors.border,
            ),
          ),
          child: _isUploadingMedia
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.textSecondary,
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, anim) =>
                      RotationTransition(turns: anim, child: child),
                  child: Icon(
                    _showCameraActions
                        ? Icons.close
                        : Icons.camera_alt_outlined,
                    key: ValueKey(_showCameraActions),
                    color: _showCameraActions
                        ? Theme.of(context).colorScheme.primary
                        : context.colors.textSecondary,
                    size: 18,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _radialOptionButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: context.colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: context.colors.textSecondary, size: 18),
      ),
    );
  }

  // Menu radial : les 3 options se déploient en quart de cercle au-dessus
  // et à droite du bouton photo (0° = tout droit, 90° = complètement à droite),
  // ancré exactement sur le bouton via _cameraButtonLink.
  Widget _cameraRadialMenu() {
    const radius = 62.0;
    const buttonSize = 40.0;
    // Voir le commentaire équivalent dans _quickActionsPopup : la popup est
    // centrée sur le bouton caméra via followerAnchor, et boxCenter sert
    // d'origine pour que les boutons restent dans la zone de hit-test.
    const boxSize = 200.0;
    const boxCenter = boxSize / 2;

    Widget option({
      required IconData icon,
      required VoidCallback? onTap,
      required double angleDeg,
      required int index,
    }) {
      final angle = angleDeg * math.pi / 180;
      final dx = radius * math.sin(angle);
      final dy = -radius * math.cos(angle);
      return Positioned(
        left: boxCenter + dx - buttonSize / 2,
        top: boxCenter + dy - buttonSize / 2,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 200 + index * 40),
          curve: Curves.easeOutBack,
          builder: (_, value, child) =>
              Transform.scale(scale: value, child: child),
          child: _radialOptionButton(icon: icon, onTap: onTap),
        ),
      );
    }

    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          option(
            icon: Icons.camera_alt_outlined,
            angleDeg: 0,
            index: 0,
            onTap: _isUploadingMedia
                ? null
                : () {
                    setState(() => _showCameraActions = false);
                    unawaited(_captureFromCamera(video: false));
                  },
          ),
          option(
            icon: Icons.videocam_outlined,
            angleDeg: 45,
            index: 1,
            onTap: _isUploadingMedia
                ? null
                : () {
                    setState(() => _showCameraActions = false);
                    unawaited(_captureFromCamera(video: true));
                  },
          ),
          option(
            icon: Icons.photo_library_outlined,
            angleDeg: 90,
            index: 2,
            onTap: _isUploadingMedia
                ? null
                : () {
                    setState(() => _showCameraActions = false);
                    unawaited(_pickFromGallery());
                  },
          ),
        ],
      ),
    );
  }

  Widget _inputIconsCluster(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [_plusIconButton(context), _cameraIconButton(context)],
    );
  }

  @override
  Widget build(BuildContext context) {
    // .value renvoie le dernier UID connu même si le provider repasse
    // brièvement en AsyncLoading (ex: rebuild déclenché par chatMessagesProvider)
    final currentUid = ref.watch(authStateProvider.select((s) => s.value?.uid));
    ref.watch(
      currentMemberProvider,
    ); // garde le provider actif pour ref.read() dans les méthodes async
    final chatAsync = ref.watch(chatMessagesProvider);
    final members =
        ref.watch(expenseMembersProvider).asData?.value ?? <GroupMember>[];

    // Marque le dernier message comme lu quand un nouveau message arrive
    // (uniquement si le chat est actif ET l'app est au premier plan).
    ref.listen(chatMessagesProvider, (_, next) {
      if (!ref.read(isChatTabActiveProvider)) return;
      if (!ref.read(appInForegroundProvider)) return;
      final msgs = next.asData?.value.messages;
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
    });

    // Marque le dernier message comme lu dès qu'on arrive sur l'onglet chat
    // (navigation depuis la nav bar ou ouverture via notification).
    ref.listen(isChatTabActiveProvider, (_, isActive) {
      if (!isActive) return;
      final msgs = ref.read(chatMessagesProvider).asData?.value.messages;
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
    });

    // Marque le dernier message comme lu quand l'app revient au premier plan
    // avec le chat déjà actif (isChatTabActive ne change pas dans ce cas).
    ref.listen(appInForegroundProvider, (_, inForeground) {
      if (!inForeground) return;
      if (!ref.read(isChatTabActiveProvider)) return;
      final msgs = ref.read(chatMessagesProvider).asData?.value.messages;
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
    });

    if (currentUid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final chatSettings =
        ref.watch(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    final bgType = chatSettings.chatBackgroundType;
    final bgValue = chatSettings.chatBackgroundValue;

    Widget buildBackground(Widget child) {
      if (bgType == 'image' && bgValue != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(bgValue, fit: BoxFit.cover),
            child,
          ],
        );
      }
      return child;
    }

    final bgColor = bgType == 'color' && bgValue != null
        ? hexToColor(bgValue)
        : context.colors.background;

    return Scaffold(
      backgroundColor: bgColor,
      body: buildBackground(
        SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // ── Search bar (optionnelle) ─────────────────────────────────
                  if (_showSearch)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: context.colors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: context.colors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Icon(
                                      Icons.search,
                                      color: context.colors.textSecondary,
                                      size: 18,
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      autofocus: true,
                                      onChanged: (v) =>
                                          setState(() => _search = v),
                                      decoration: InputDecoration(
                                        hintText: 'Rechercher dans le chat...',
                                        hintStyle: TextStyle(
                                          color: context.colors.textSecondary,
                                          fontSize: 14,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                        filled: false,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() {
                              _showSearch = false;
                              _search = '';
                            }),
                            child: Icon(
                              Icons.close,
                              color: context.colors.textSecondary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // ── Messages ────────────────────────────────────────────────
                  Expanded(
                    child: chatAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Erreur: $e')),
                      data: (chatState) {
                        final allMessages = chatState.messages;
                        final messages = _search.isEmpty
                            ? allMessages
                            : allMessages.where((m) {
                                final q = _search.toLowerCase();
                                final textContent = m.type == MessageType.text
                                    ? m.content.toLowerCase()
                                    : '';
                                return textContent.contains(q) ||
                                    (m.senderName?.toLowerCase().contains(q) ??
                                        false);
                              }).toList();
                        if (messages.isEmpty) {
                          return Center(
                            child: Text(
                              'Aucun message. Soyez le premier !',
                              style: TextStyle(
                                color: context.colors.textSecondary,
                              ),
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

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          itemCount:
                              messages.length + (chatState.loadingMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == messages.length) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              );
                            }

                            final msg = messages[i];
                            final isMe = msg.senderId == currentUid;

                            final newerMsg = i > 0 ? messages[i - 1] : null;
                            final olderMsg = i < messages.length - 1
                                ? messages[i + 1]
                                : null;

                            final isFirstInGroup =
                                newerMsg == null ||
                                !_isSameGroup(msg, newerMsg);
                            final isLastInGroup =
                                olderMsg == null ||
                                !_isSameGroup(olderMsg, msg);

                            final isPoll = msg.type == MessageType.poll;
                            final seenBy = seenByMessage[msg.id] ?? [];

                            return Column(
                              key: _keyForMessage(msg.id),
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: seenBy.isEmpty && isFirstInGroup
                                        ? 10
                                        : 2,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    decoration: BoxDecoration(
                                      color: _highlightedMessageId == msg.id
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.13)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: SwipeToReply(
                                      isMe: isMe,
                                      onReply:
                                          msg.type != MessageType.system &&
                                              !isPoll
                                          ? () => setState(
                                              () => _replyingTo = msg,
                                            )
                                          : null,
                                      child: MessageBubble(
                                        message: msg,
                                        isMe: isMe,
                                        currentUserId: currentUid,
                                        showTimestamp: _visibleTimestamps
                                            .contains(msg.id),
                                        showAvatar: !isMe && isFirstInGroup,
                                        showSenderName: !isMe && isLastInGroup,
                                        isFirstInGroup: isFirstInGroup,
                                        isLastInGroup: isLastInGroup,
                                        member: members
                                            .where((m) => m.uid == msg.senderId)
                                            .firstOrNull,
                                        members: members,
                                        resolvedReplyContent:
                                            msg.replyToId != null
                                            ? messages
                                                  .where(
                                                    (m) =>
                                                        m.id == msg.replyToId,
                                                  )
                                                  .firstOrNull
                                                  ?.content
                                            : null,
                                        onTap:
                                            msg.type != MessageType.system &&
                                                !isPoll
                                            ? () => _toggleTimestamp(msg.id)
                                            : null,
                                        onDoubleTap:
                                            msg.type != MessageType.system &&
                                                !isPoll
                                            ? () => _onDoubleTap(msg)
                                            : null,
                                        onLongPress:
                                            msg.type != MessageType.system
                                            ? () =>
                                                  _onMessageLongPress(msg, isMe)
                                            : null,
                                        onVote: isPoll
                                            ? (idx) => _votePoll(msg, idx)
                                            : null,
                                        hasCustomBackground:
                                            bgType != null && bgType != 'none',
                                        onReplyPreviewTap: msg.replyToId != null
                                            ? () => _scrollToMessage(
                                                msg.replyToId,
                                                messages,
                                              )
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
                      },
                    ),
                  ),

                  // ── Typing indicator ────────────────────────────────────────
                  TypingIndicator(
                    typingUsers: ref.watch(typingProvider).asData?.value ?? [],
                  ),

                  // ── Edit bar ────────────────────────────────────────────────
                  if (_editingMessage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: context.colors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Modifier le message',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: context.colors.textSecondary,
                            onPressed: () => setState(() {
                              _editingMessage = null;
                              _controller.clear();
                            }),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                  // ── Reply bar ───────────────────────────────────────────────
                  if (_replyingTo != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: context.colors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _replyingTo!.senderName ?? '',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _replyingTo!.type == MessageType.image
                                      ? 'Photo'
                                      : _replyingTo!.type == MessageType.file
                                      ? 'Fichier'
                                      : _replyingTo!.type == MessageType.audio
                                      ? 'Audio'
                                      : _replyingTo!.type == MessageType.poll
                                      ? 'Sondage'
                                      : _replyingTo!.content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: context.colors.textSecondary,
                            onPressed: () => setState(() => _replyingTo = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                  // ── Input bar ───────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 24, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: context.colors.border),
                      ),
                    ),
                    child: _isRecording
                        // ── Recording mode ────────────────────────────────────
                        ? Row(
                            children: [
                              GestureDetector(
                                onTap: _cancelRecording,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  margin: const EdgeInsets.only(
                                    right: 12,
                                    bottom: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.background,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: context.colors.border,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _fmtDuration(_recordingDuration),
                                      style: TextStyle(
                                        color: context.colors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Enregistrement…',
                                      style: TextStyle(
                                        color: context.colors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: _stopAndSendAudio,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        darken(
                                          Theme.of(context).colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
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
                                    border: Border.all(
                                      color: context.colors.border,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _controller,
                                    focusNode: _inputFocusNode,
                                    decoration: InputDecoration(
                                      hintText: 'Écrire un message...',
                                      hintStyle: TextStyle(
                                        color: context.colors.textSecondary,
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
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
                                GestureDetector(
                                  onTap: _startRecording,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Theme.of(context).colorScheme.primary,
                                          darken(
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: _isUploading
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.mic,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                  ),
                                )
                              else
                                GestureDetector(
                                  onTap: _send,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Theme.of(context).colorScheme.primary,
                                          darken(
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: _sending
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.send,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
              if (_showQuickActions)
                CompositedTransformFollower(
                  link: _plusButtonLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.topCenter,
                  followerAnchor: Alignment.center,
                  child: _quickActionsPopup(context),
                ),
              if (_showCameraActions)
                CompositedTransformFollower(
                  link: _cameraButtonLink,
                  followerAnchor: Alignment.center,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.topCenter,
                  child: _cameraRadialMenu(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
