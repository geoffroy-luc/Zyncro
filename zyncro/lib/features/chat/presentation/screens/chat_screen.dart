import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/group_member.dart';
import '../../../../shared/models/message.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../domain/repositories/i_messages_repository.dart';
import '../providers/messages_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import 'media_viewer_screen.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  Timer? _typingTimer;
  final Set<String> _visibleTimestamps = {};
  Message? _replyingTo;

  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isUploading = false;
  bool _isUploadingMedia = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // Sauvegardés pour pouvoir les utiliser dans dispose() sans ref
  String? _currentGroupId;
  String? _currentUserId;
  IMessagesRepository? _repo;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
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

    repo.setTyping(
      groupId: groupId,
      userId: user.uid,
      userName: ref.read(currentMemberProvider).asData?.value?.displayName ??
          user.displayName ??
          user.email ??
          'Anonyme',
    );

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), _clearTyping);
  }

  void _clearTyping() {
    final groupId = _currentGroupId;
    final userId = _currentUserId;
    final repo = _repo;
    if (groupId == null || userId == null || repo == null) return;
    repo.clearTyping(groupId: groupId, userId: userId);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _recorder.dispose();
    _clearTyping();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
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
            senderName: ref.read(currentMemberProvider).asData?.value?.displayName ??
                user.displayName ??
                user.email ??
                'Anonyme',
            content: text,
            replyToId: reply?.id,
            replyToSenderName: reply?.senderName,
            replyToContent: reply?.content,
          );
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static const _quickEmojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];

  static bool _isSameGroup(Message older, Message newer) {
    if (older.senderId == null || older.senderId != newer.senderId) return false;
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
    await ref.read(messagesRepositoryProvider).toggleReaction(
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
                            ? const Color(0xFFE85D75).withValues(alpha: 0.15)
                            : const Color(0xFFF7F9FC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasReacted
                              ? const Color(0xFFE85D75)
                              : AppColors.border,
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
      await ref.read(messagesRepositoryProvider).toggleReaction(
            groupId: groupId,
            messageId: message.id,
            emoji: emoji,
            userId: currentUser.uid,
            hasReacted: hasReacted,
          );
      return;
    }
    if (action == 'edit') {
      await _editMessage(message);
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

  Future<void> _editMessage(Message message) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;

    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditMessageDialog(initialText: message.content),
    );

    final updated = newText?.trim();
    if (updated == null || updated.isEmpty || updated == message.content) {
      return;
    }

    try {
      await ref
          .read(messagesRepositoryProvider)
          .editMessage(
            groupId: groupId,
            messageId: message.id,
            content: updated,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de modifier le message.')),
      );
    }
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
      builder: (ctx) => _EditPollDialog(
        question: question,
        options: options,
        multipleChoice: multipleChoice,
      ),
    );
    if (result == null || !mounted) return;

    try {
      await ref.read(messagesRepositoryProvider).editPoll(
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
    final hasVoted =
        message.reactions[key]?.contains(currentUser.uid) == true;

    bool multipleChoice = false;
    try {
      final data = jsonDecode(message.content) as Map<String, dynamic>;
      multipleChoice = data['multipleChoice'] as bool? ?? false;
    } catch (_) {}

    await ref.read(messagesRepositoryProvider).toggleReaction(
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
      builder: (ctx) => const _CreatePollDialog(),
    );
    if (result == null || !mounted) return;

    await ref.read(messagesRepositoryProvider).sendPoll(
          groupId: groupId,
          senderId: user.uid,
          senderName: ref.read(currentMemberProvider).asData?.value?.displayName ??
              user.displayName ??
              user.email ??
              'Anonyme',
          question: result['question'] as String,
          options: List<String>.from(result['options'] as List),
          multipleChoice: result['multipleChoice'] as bool? ?? false,
        );

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
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
          const SnackBar(
            content: Text('Permission microphone refusée.'),
          ),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
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
      await ref.read(messagesRepositoryProvider).sendAudio(
            groupId: groupId,
            senderId: user.uid,
            senderName: ref.read(currentMemberProvider).asData?.value?.displayName ??
                user.displayName ??
                user.email ??
                'Anonyme',
            filePath: path,
            durationSeconds: duration.inSeconds,
          );
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pasteAndSendImage() async {
    final imageBytes = await Pasteboard.image;
    if (imageBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune image dans le presse-papier')),
        );
      }
      return;
    }

    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (user == null || groupId == null) return;

    final reply = _replyingTo;
    setState(() {
      _isUploadingMedia = true;
      _replyingTo = null;
    });

    try {
      final dir = await getTemporaryDirectory();
      final rawPath = '${dir.path}/paste_${DateTime.now().millisecondsSinceEpoch}.png';
      final rawFile = await File(rawPath).writeAsBytes(imageBytes);

      final targetPath = '${dir.path}/paste_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressed = await FlutterImageCompress.compressAndGetFile(
        rawFile.path,
        targetPath,
        quality: 85,
        minWidth: 1920,
        minHeight: 1920,
        keepExif: false,
      );
      final uploadPath = compressed?.path ?? rawFile.path;

      await ref.read(messagesRepositoryProvider).sendMedia(
            groupId: groupId,
            senderId: user.uid,
            senderName: ref.read(currentMemberProvider).asData?.value?.displayName ??
                user.displayName ??
                user.email ??
                'Anonyme',
            filePath: uploadPath,
            mimeType: 'image/jpeg',
            replyToId: reply?.id,
            replyToSenderName: reply?.senderName,
            replyToContent: reply?.content,
          );
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur collage image : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _pickAndSendMedia() async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_paste_outlined),
              title: const Text('Coller une image'),
              onTap: () => Navigator.of(ctx).pop('paste'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo depuis la galerie'),
              onTap: () => Navigator.of(ctx).pop('gallery_photo'),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Vidéo depuis la galerie'),
              onTap: () => Navigator.of(ctx).pop('gallery_video'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Enregistrer une vidéo'),
              onTap: () => Navigator.of(ctx).pop('video'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'paste') {
      await _pasteAndSendImage();
      return;
    }

    XFile? file;
    String mimeType;
    if (choice == 'gallery_photo') {
      file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (file == null) return;
      mimeType = 'image/jpeg';
    } else if (choice == 'gallery_video') {
      file = await picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;
      mimeType = 'video/mp4';
    } else if (choice == 'camera') {
      file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      mimeType = 'image/jpeg';
    } else {
      file = await picker.pickVideo(source: ImageSource.camera);
      mimeType = 'video/mp4';
    }
    if (file == null || !mounted) return;

    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (user == null || groupId == null) return;

    final reply = _replyingTo;
    setState(() {
      _isUploadingMedia = true;
      _replyingTo = null;
    });

    try {
      // Compression pour les images uniquement
      String uploadPath = file.path;
      if (mimeType.startsWith('image/')) {
        final dir = await getTemporaryDirectory();
        final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final compressed = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          quality: 85,
          minWidth: 1920,
          minHeight: 1920,
          keepExif: false,
        );
        if (compressed != null) {
          uploadPath = compressed.path;
          mimeType = 'image/jpeg';
        }
      }

      await ref.read(messagesRepositoryProvider).sendMedia(
            groupId: groupId,
            senderId: user.uid,
            senderName: ref.read(currentMemberProvider).asData?.value?.displayName ??
                user.displayName ??
                user.email ??
                'Anonyme',
            filePath: uploadPath,
            mimeType: mimeType,
            replyToId: reply?.id,
            replyToSenderName: reply?.senderName,
            replyToContent: reply?.content,
          );
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur envoi média : $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    // .value renvoie le dernier UID connu même si le provider repasse
    // brièvement en AsyncLoading (ex: rebuild déclenché par messagesProvider)
    final currentUid = ref.watch(
      authStateProvider.select((s) => s.value?.uid),
    );
    ref.watch(currentMemberProvider); // garde le provider actif pour ref.read() dans les méthodes async
    final messagesAsync = ref.watch(messagesProvider);
    final members = ref.watch(expenseMembersProvider).asData?.value ?? <GroupMember>[];

    // Marque le dernier message comme lu quand un nouveau message arrive
    // (uniquement si le chat est actif ET l'app est au premier plan).
    ref.listen(messagesProvider, (_, next) {
      if (!ref.read(isChatTabActiveProvider)) return;
      if (!ref.read(appInForegroundProvider)) return;
      final msgs = next.asData?.value;
      if (msgs == null || msgs.isEmpty) return;
      final groupId = ref.read(selectedGroupIdProvider).asData?.value;
      final userId = ref.read(authStateProvider).asData?.value?.uid;
      if (groupId == null || userId == null) return;
      ref.read(messagesRepositoryProvider).markAsRead(
            groupId: groupId,
            userId: userId,
            messageId: msgs.first.id,
            messageTimestamp: msgs.first.timestamp,
          );
    });

    // Marque le dernier message comme lu dès qu'on arrive sur l'onglet chat
    // (navigation depuis la nav bar ou ouverture via notification).
    ref.listen(isChatTabActiveProvider, (_, isActive) {
      if (!isActive) return;
      final msgs = ref.read(messagesProvider).asData?.value;
      if (msgs == null || msgs.isEmpty) return;
      final groupId = ref.read(selectedGroupIdProvider).asData?.value;
      final userId = ref.read(authStateProvider).asData?.value?.uid;
      if (groupId == null || userId == null) return;
      ref.read(messagesRepositoryProvider).markAsRead(
            groupId: groupId,
            userId: userId,
            messageId: msgs.first.id,
            messageTimestamp: msgs.first.timestamp,
          );
    });

    // Marque le dernier message comme lu quand l'app revient au premier plan
    // avec le chat déjà actif (isChatTabActive ne change pas dans ce cas).
    ref.listen(appInForegroundProvider, (_, inForeground) {
      if (!inForeground) return;
      if (!ref.read(isChatTabActiveProvider)) return;
      final msgs = ref.read(messagesProvider).asData?.value;
      if (msgs == null || msgs.isEmpty) return;
      final groupId = ref.read(selectedGroupIdProvider).asData?.value;
      final userId = ref.read(authStateProvider).asData?.value?.uid;
      if (groupId == null || userId == null) return;
      ref.read(messagesRepositoryProvider).markAsRead(
            groupId: groupId,
            userId: userId,
            messageId: msgs.first.id,
            messageTimestamp: msgs.first.timestamp,
          );
    });

    if (currentUid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Column(
        children: [
          // ── Messages ────────────────────────────────────────────────
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun message. Soyez le premier !',
                      style: TextStyle(color: AppColors.textSecondary),
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
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == currentUid;

                    final newerMsg = i > 0 ? messages[i - 1] : null;
                    final olderMsg =
                        i < messages.length - 1 ? messages[i + 1] : null;

                    final isFirstInGroup =
                        newerMsg == null || !_isSameGroup(msg, newerMsg);
                    final isLastInGroup =
                        olderMsg == null || !_isSameGroup(olderMsg, msg);

                    final isPoll = msg.type == MessageType.poll;
                    final seenBy = seenByMessage[msg.id] ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: seenBy.isEmpty && isFirstInGroup ? 10 : 2,
                          ),
                          child: _SwipeToReply(
                            isMe: isMe,
                            onReply: msg.type != MessageType.system && !isPoll
                                ? () => setState(() => _replyingTo = msg)
                                : null,
                            child: _MessageBubble(
                              message: msg,
                              isMe: isMe,
                              currentUserId: currentUid,
                              showTimestamp: _visibleTimestamps.contains(msg.id),
                              showAvatar: !isMe && isFirstInGroup,
                              showSenderName: !isMe && isLastInGroup,
                              isFirstInGroup: isFirstInGroup,
                              isLastInGroup: isLastInGroup,
                              member: members.where((m) => m.uid == msg.senderId).firstOrNull,
                              members: members,
                              onTap: msg.type != MessageType.system && !isPoll
                                  ? () => _toggleTimestamp(msg.id)
                                  : null,
                              onDoubleTap: msg.type != MessageType.system && !isPoll
                                  ? () => _onDoubleTap(msg)
                                  : null,
                              onLongPress: msg.type != MessageType.system
                                  ? () => _onMessageLongPress(msg, isMe)
                                  : null,
                              onVote: isPoll
                                  ? (idx) => _votePoll(msg, idx)
                                  : null,
                            ),
                          ),
                        ),
                        if (seenBy.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: isFirstInGroup ? 10 : 2,
                              right: 4,
                            ),
                            child: _SeenByRow(members: seenBy),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── Typing indicator ────────────────────────────────────────
          _TypingIndicator(
            typingUsers: ref.watch(typingProvider).asData?.value ?? [],
          ),

          // ── Reply bar ───────────────────────────────────────────────
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE85D75),
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
                          style: const TextStyle(
                            color: Color(0xFFE85D75),
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
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.textSecondary,
                    onPressed: () => setState(() => _replyingTo = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // ── Input bar ───────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(12, 12, 24, 12 + bottomPad),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
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
                          margin: const EdgeInsets.only(right: 12, bottom: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FC),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
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
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Enregistrement…',
                              style: TextStyle(
                                color: AppColors.textSecondary,
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
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFE85D75), Color(0xFFC94060)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE85D75)
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
                GestureDetector(
                  onTap: _showCreatePoll,
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 8, bottom: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.poll_outlined,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _isUploadingMedia ? null : _pickAndSendMedia,
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 8, bottom: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: _isUploadingMedia
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : const Icon(
                            Icons.image_outlined,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Écrire un message...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        filled: false,
                        isDense: true,
                      ),
                      maxLines: 4,
                      minLines: 1,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
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
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFE85D75), Color(0xFFC94060)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE85D75).withValues(alpha: 0.25),
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
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE85D75), Color(0xFFC94060)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE85D75).withValues(alpha: 0.25),
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
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditMessageDialog extends StatefulWidget {
  final String initialText;

  const _EditMessageDialog({required this.initialText});

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le message'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 6,
        decoration: const InputDecoration(
          hintText: 'Votre message',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final List<String> typingUsers;

  const _TypingIndicator({required this.typingUsers});

  @override
  Widget build(BuildContext context) {
    if (typingUsers.isEmpty) return const SizedBox.shrink();

    final String label;
    if (typingUsers.length == 1) {
      label = '${typingUsers[0]} est en train d\'écrire...';
    } else if (typingUsers.length == 2) {
      label =
          '${typingUsers[0]} et ${typingUsers[1]} sont en train d\'écrire...';
    } else {
      label = 'Plusieurs personnes sont en train d\'écrire...';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      color: Colors.white,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? currentUserId;
  final bool showTimestamp;
  final bool showAvatar;
  final bool showSenderName;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final GroupMember? member;
  final List<GroupMember> members;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(int)? onVote;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showTimestamp,
    required this.showAvatar,
    required this.showSenderName,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    this.member,
    this.members = const [],
    this.currentUserId,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onVote,
  });

  static final _urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);

  static String _cleanUrl(String url) =>
      url.replaceAll(RegExp(r'[.,;:!?)\]>]+$'), '');

  static Future<void> _openUrl(String raw) async {
    final url = _cleanUrl(raw);
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Widget _messageContent(BuildContext context, bool isMe) {
    if (message.type == MessageType.audio) {
      try {
        final data = jsonDecode(message.content) as Map<String, dynamic>;
        return _AudioPlayerWidget(
          key: ValueKey(message.id),
          url: data['url'] as String? ?? '',
          durationSeconds: (data['duration'] as num?)?.toInt() ?? 0,
          isMe: isMe,
        );
      } catch (_) {
        return Text(
          '🎵 Audio',
          style: TextStyle(
            color: isMe ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
          ),
        );
      }
    }
    if (message.type == MessageType.image) {
      try {
        final data = jsonDecode(message.content) as Map<String, dynamic>;
        final url = data['url'] as String? ?? '';
        return GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => ImageViewerScreen(
              url: url,
              senderName: message.senderName,
              sentAt: message.timestamp,
            )),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 220,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : SizedBox(
                      width: 220,
                      height: 160,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          color: isMe ? Colors.white : const Color(0xFFE85D75),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
              errorBuilder: (_, __, ___) => Text(
                '🖼️ Image',
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      } catch (_) {
        return Text(
          '🖼️ Image',
          style: TextStyle(
            color: isMe ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
          ),
        );
      }
    }
    if (message.type == MessageType.file) {
      try {
        final data = jsonDecode(message.content) as Map<String, dynamic>;
        final url = data['url'] as String? ?? '';
        return GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => VideoViewerScreen(
              url: url,
              senderName: message.senderName,
              sentAt: message.timestamp,
            )),
          ),
          child: _VideoThumbnail(key: ValueKey(message.id), url: url),
        );
      } catch (_) {
        return Text(
          '🎥 Vidéo',
          style: TextStyle(
            color: isMe ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
          ),
        );
      }
    }
    final urls = _urlRegex
        .allMatches(message.content)
        .map((m) => _cleanUrl(m.group(0)!))
        .where((u) => u.isNotEmpty)
        .toList();

    final textWidget = _LinkedText(text: message.content, isMe: isMe);

    if (urls.isEmpty) return textWidget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        textWidget,
        const SizedBox(height: 8),
        _LinkPreviewWidget(url: urls.first, isMe: isMe),
      ],
    );
  }

  String _formatTime(DateTime dt) => DateFormat('HH:mm').format(dt);

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.poll) {
      return _PollCard(
        message: message,
        isMe: isMe,
        currentUserId: currentUserId,
        onVote: onVote,
        onLongPress: onLongPress,
      );
    }

    if (message.type == MessageType.system) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final timeLabel = message.editedAt == null
        ? _formatTime(message.timestamp)
        : '${_formatTime(message.timestamp)} · modifié';

    final reactionsRow = message.reactions.isNotEmpty
        ? _ReactionsRow(
            reactions: message.reactions,
            currentUserId: currentUserId,
            members: members,
          )
        : null;

    // ── Timestamp flottant (visible au tap) ──────────────────────────
    final timestampWidget = showTimestamp
        ? Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Center(
              child: Text(
                timeLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          )
        : null;

    final isMedia = message.type == MessageType.image || message.type == MessageType.file;

    if (isMe) {
      // Border radius selon position dans le groupe
      final radius = BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: Radius.circular(isLastInGroup ? 16 : 4),
        bottomLeft: const Radius.circular(16),
        bottomRight: Radius.circular(isFirstInGroup ? 4 : 4),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (timestampWidget != null) timestampWidget,
          GestureDetector(
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onLongPress: onLongPress,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: isMedia
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMedia
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE85D75), Color(0xFFC94060)],
                      ),
                borderRadius: radius,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.replyToContent != null)
                    _ReplyPreview(
                      senderName: message.replyToSenderName,
                      content: message.replyToContent!,
                      isMe: true,
                    ),
                  _messageContent(context, true),
                ],
              ),
            ),
          ),
          if (reactionsRow != null) ...[
            const SizedBox(height: 4),
            reactionsRow,
          ],
        ],
      );
    }

    // ── Message reçu ────────────────────────────────────────────────
    final avatarColor = avatarColorForUid(message.senderId ?? '');

    final radius = BorderRadius.only(
      topLeft: Radius.circular(isLastInGroup ? 16 : 4),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isFirstInGroup ? 16 : 4),
      bottomRight: const Radius.circular(16),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSenderName)
          Padding(
            padding: const EdgeInsets.only(left: 46, bottom: 2),
            child: Text(
              member?.displayName ?? message.senderName ?? '',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        if (timestampWidget != null) timestampWidget,
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar ou placeholder pour maintenir l'alignement
            if (showAvatar)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: UserAvatar(
                  photoUrl: member?.photoUrl,
                  showPhoto: member?.showProfilePhoto ?? true,
                  displayName: member?.displayName ?? message.senderName ?? '?',
                  radius: 15,
                  color: avatarColor,
                ),
              )
            else
              const SizedBox(width: 38),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  onDoubleTap: onDoubleTap,
                  onLongPress: onLongPress,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    padding: isMedia
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: radius,
                      border: isMedia ? null : Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.replyToContent != null)
                          _ReplyPreview(
                            senderName: message.replyToSenderName,
                            content: message.replyToContent!,
                            isMe: false,
                          ),
                        _messageContent(context, false),
                      ],
                    ),
                  ),
                ),
                if (reactionsRow != null) ...[
                  const SizedBox(height: 4),
                  reactionsRow,
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ── Texte avec liens cliquables ──────────────────────────────────────────────

class _LinkedText extends StatefulWidget {
  final String text;
  final bool isMe;

  const _LinkedText({required this.text, required this.isMe});

  @override
  State<_LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<_LinkedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final text = widget.text;
    final isMe = widget.isMe;
    final matches = _MessageBubble._urlRegex.allMatches(text).toList();
    final textColor = isMe ? Colors.white : AppColors.textPrimary;
    final linkColor = isMe ? Colors.white : const Color(0xFF1D6AE5);
    final textStyle = TextStyle(color: textColor, fontSize: 14, height: 1.4);

    if (matches.isEmpty) {
      return Text(text, style: textStyle);
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: textStyle,
        ));
      }
      final url = _MessageBubble._cleanUrl(match.group(0)!);
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _MessageBubble._openUrl(url);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: url,
        style: textStyle.copyWith(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
        recognizer: recognizer,
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: textStyle,
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// ── Prévisualisation de lien ─────────────────────────────────────────────────

class _LinkPreviewWidget extends StatefulWidget {
  final String url;
  final bool isMe;

  const _LinkPreviewWidget({required this.url, required this.isMe});

  @override
  State<_LinkPreviewWidget> createState() => _LinkPreviewWidgetState();
}

class _LinkPreviewWidgetState extends State<_LinkPreviewWidget> {
  _LinkMeta? _meta;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMeta();
  }

  Future<void> _fetchMeta() async {
    try {
      final response = await http
          .get(
            Uri.parse(widget.url),
            headers: {'User-Agent': 'Mozilla/5.0 (compatible; Zyncro/1.0)'},
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final body = response.body;
        final meta = _LinkMeta(
          title: _ogTag(body, 'og:title') ?? _htmlTitle(body),
          description:
              _ogTag(body, 'og:description') ?? _metaTag(body, 'description'),
          imageUrl: _ogTag(body, 'og:image'),
          siteName: _ogTag(body, 'og:site_name') ??
              Uri.parse(widget.url).host.replaceFirst('www.', ''),
        );
        if (mounted) setState(() { _meta = meta; _loading = false; });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _ogTag(String html, String property) {
    final r1 = RegExp(
      'property=["\']${RegExp.escape(property)}["\'][^>]*content=["\']([^"\']*)["\']',
      caseSensitive: false,
    );
    final r2 = RegExp(
      'content=["\']([^"\']*)["\'][^>]*property=["\']${RegExp.escape(property)}["\']',
      caseSensitive: false,
    );
    return (r1.firstMatch(html) ?? r2.firstMatch(html))?.group(1)?.trim();
  }

  String? _metaTag(String html, String name) {
    final r1 = RegExp(
      'name=["\']${RegExp.escape(name)}["\'][^>]*content=["\']([^"\']*)["\']',
      caseSensitive: false,
    );
    final r2 = RegExp(
      'content=["\']([^"\']*)["\'][^>]*name=["\']${RegExp.escape(name)}["\']',
      caseSensitive: false,
    );
    return (r1.firstMatch(html) ?? r2.firstMatch(html))?.group(1)?.trim();
  }

  String? _htmlTitle(String html) =>
      RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
          .firstMatch(html)
          ?.group(1)
          ?.trim();

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    final meta = _meta;
    if (meta == null ||
        (meta.title == null &&
            meta.description == null &&
            meta.imageUrl == null)) {
      return const SizedBox.shrink();
    }
    return _buildCard(meta);
  }

  Widget _buildLoading() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withValues(alpha: 0.15)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: widget.isMe ? Colors.white54 : const Color(0xFFE85D75),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(_LinkMeta meta) {
    final isMe = widget.isMe;
    final borderColor =
        isMe ? Colors.white.withValues(alpha: 0.6) : const Color(0xFFE85D75);
    final bgColor = isMe
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFF3F4F6);
    final titleColor = isMe ? Colors.white : AppColors.textPrimary;
    final subColor = isMe ? Colors.white70 : AppColors.textSecondary;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(widget.url);
        if (uri != null) {
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {}
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: borderColor, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (meta.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(8),
                ),
                child: Image.network(
                  meta.imageUrl!,
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (meta.siteName != null)
                    Text(
                      meta.siteName!,
                      style: TextStyle(
                        color: subColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (meta.title != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta.title!,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (meta.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta.description!,
                      style: TextStyle(color: subColor, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkMeta {
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  const _LinkMeta({
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });
}

// ── Vignette vidéo (premier frame) ──────────────────────────────────────────

class _VideoThumbnail extends StatefulWidget {
  final String url;
  const _VideoThumbnail({super.key, required this.url});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  late VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          _controller.seekTo(Duration.zero);
          setState(() => _ready = true);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 220,
        height: 130,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            else
              const ColoredBox(color: Color(0xFF1A1A1A)),
            const Center(
              child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Seen-by row (petites PP sous le dernier message lu) ─────────────────────
class _SeenByRow extends StatelessWidget {
  final List<GroupMember> members;

  const _SeenByRow({required this.members});

  static const int _maxVisible = 6;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(_maxVisible).toList();
    final overflow = members.length - _maxVisible;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visible.map(
          (m) => Padding(
            padding: const EdgeInsets.only(left: 2),
            child: UserAvatar(
              photoUrl: m.photoUrl,
              showPhoto: m.showProfilePhoto,
              displayName: m.displayName,
              radius: 7,
              color: avatarColorForUid(m.uid),
            ),
          ),
        ),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '+$overflow',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReactionsRow extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final String? currentUserId;
  final List<GroupMember> members;

  const _ReactionsRow({
    required this.reactions,
    this.currentUserId,
    this.members = const [],
  });

  void _showReactionDetails(BuildContext context) {
    final entries = reactions.entries.where((e) => e.value.isNotEmpty).toList();
    final nameByUid = {for (final m in members) m.uid: m.displayName};

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Réactions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...entries.map((e) {
              final emoji = e.key;
              final uids = e.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        '${uids.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...uids.map((uid) {
                    final name = uid == currentUserId
                        ? 'Vous'
                        : (nameByUid[uid] ?? uid);
                    return Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = reactions.entries.where((e) => e.value.isNotEmpty).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: entries.map((e) {
        final emoji = e.key;
        final users = e.value;
        final isMine = currentUserId != null && users.contains(currentUserId);

        return GestureDetector(
          onTap: () => _showReactionDetails(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isMine
                  ? const Color(0xFFE85D75).withValues(alpha: 0.15)
                  : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMine
                    ? const Color(0xFFE85D75).withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 3),
                Text(
                  '${users.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isMine
                        ? const Color(0xFFC94060)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Reply preview (dans la bulle) ────────────────────────────────────────────

class _ReplyPreview extends StatelessWidget {
  final String? senderName;
  final String content;
  final bool isMe;

  const _ReplyPreview({
    required this.content,
    required this.isMe,
    this.senderName,
  });

  String _formatReplyContent(String c) {
    if (c.startsWith('http')) return 'Photo / Vidéo';
    if (c.startsWith('{')) return 'Sondage';
    return c;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.2)
            : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe
                ? Colors.white.withValues(alpha: 0.7)
                : const Color(0xFFE85D75),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (senderName != null)
            Text(
              senderName!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.9)
                    : const Color(0xFFE85D75),
              ),
            ),
          Text(
            _formatReplyContent(content),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMe
                  ? Colors.white.withValues(alpha: 0.75)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Swipe to reply ────────────────────────────────────────────────────────────

class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;
  final bool isMe;

  const _SwipeToReply({required this.child, required this.isMe, this.onReply});

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  // Valeur signée : positif = droite (messages reçus), négatif = gauche (mes messages)
  double _dragX = 0;
  bool _triggered = false;
  late final AnimationController _controller;
  Animation<double>? _resetAnimation;

  static const _threshold = 56.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (widget.onReply == null) return;
    // isMe → swipe gauche (dx négatif vers le centre)
    // !isMe → swipe droite (dx positif vers le centre)
    final delta = widget.isMe ? d.delta.dx : d.delta.dx;
    final wrongDirection = widget.isMe ? delta > 0 : delta < 0;
    if (wrongDirection && _dragX == 0) return;

    _resetAnimation?.removeListener(_onResetTick);
    _controller.stop();
    setState(() {
      if (widget.isMe) {
        _dragX = (_dragX + delta).clamp(-_threshold, 0.0);
      } else {
        _dragX = (_dragX + delta).clamp(0.0, _threshold);
      }
    });
    if (_dragX.abs() >= _threshold && !_triggered) {
      _triggered = true;
      HapticFeedback.lightImpact();
      widget.onReply?.call();
    }
  }

  void _onResetTick() {
    if (mounted) setState(() => _dragX = _resetAnimation!.value);
  }

  void _onDragEnd(DragEndDetails _) {
    _triggered = false;
    _resetAnimation?.removeListener(_onResetTick);
    _resetAnimation = Tween<double>(begin: _dragX, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    )..addListener(_onResetTick);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final absX = _dragX.abs();
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: SizedBox(
        width: double.infinity,
        child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.translate(
            offset: Offset(_dragX, 0),
            child: SizedBox(width: double.infinity, child: widget.child),
          ),
          if (absX > 8)
            Positioned(
              // isMe : icône à droite du message (côté centre)
              // !isMe : icône à gauche du message (côté centre)
              left: widget.isMe ? null : absX - 28,
              right: widget.isMe ? absX - 28 : null,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: (absX / _threshold).clamp(0.0, 1.0),
                child: const Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.reply_rounded,
                    color: Color(0xFFE85D75),
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

// ── Audio player widget ───────────────────────────────────────────────────────

class _AudioPlayerWidget extends StatefulWidget {
  final String url;
  final int durationSeconds;
  final bool isMe;

  const _AudioPlayerWidget({
    super.key,
    required this.url,
    required this.durationSeconds,
    required this.isMe,
  });

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  late final AudioPlayer _player;
  double _speed = 1.0;
  double _lastTapDx = 0;
  bool _urlLoaded = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
  }

  Future<void> _ensureUrlLoaded() async {
    if (_isDisposed || _urlLoaded || widget.url.isEmpty) return;
    _urlLoaded = true;
    try {
      await _player.setUrl(widget.url);
    } catch (_) {
      if (!_isDisposed) _urlLoaded = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _seekTo(double dx, double width) {
    final total = _player.duration;
    if (total == null || total.inMilliseconds == 0) return;
    final ratio = (dx / width).clamp(0.0, 1.0);
    _player.seek(Duration(milliseconds: (total.inMilliseconds * ratio).round()));
  }

  void _toggleSpeed() {
    final next = _speed == 1.0 ? 2.0 : 1.0;
    setState(() => _speed = next);
    _player.setSpeed(next);
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Duration(seconds: widget.durationSeconds);

    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, stateSnap) {
        final state = stateSnap.data;
        final isPlaying = state?.playing ?? false;
        final isLoading = state?.processingState == ProcessingState.loading ||
            state?.processingState == ProcessingState.buffering;

        return StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, posSnap) {
            final position = posSnap.data ?? Duration.zero;
            final total = _player.duration ?? fallback;
            final progress = total.inMilliseconds > 0
                ? (position.inMilliseconds / total.inMilliseconds)
                    .clamp(0.0, 1.0)
                : 0.0;

            final fg =
                widget.isMe ? Colors.white : const Color(0xFFE85D75);
            final fgFaded = widget.isMe
                ? Colors.white.withValues(alpha: 0.35)
                : const Color(0xFFE85D75).withValues(alpha: 0.25);

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: isLoading
                      ? null
                      : () async {
                          if (isPlaying) {
                            await _player.pause();
                          } else {
                            await _ensureUrlLoaded();
                            if (!mounted) return;
                            if (_player.processingState ==
                                ProcessingState.completed) {
                              await _player.seek(Duration.zero);
                            }
                            if (!mounted) return;
                            await _player.play();
                          }
                        },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.isMe
                          ? Colors.white.withValues(alpha: 0.25)
                          : const Color(0xFFE85D75).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(9),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: fg,
                            ),
                          )
                        : Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 20,
                            color: fg,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            // onTap consomme l'événement → empêche l'affichage
                            // du timestamp par le parent
                            onTap: () =>
                                _seekTo(_lastTapDx, constraints.maxWidth),
                            onTapDown: (d) {
                              _lastTapDx = d.localPosition.dx;
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: fgFaded,
                                  valueColor: AlwaysStoppedAnimation(fg),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${_fmt(position)} / ${_fmt(total)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: widget.isMe
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          // ── -5s ──
                          GestureDetector(
                            onTap: () {
                              final t = position - const Duration(seconds: 5);
                              _player.seek(
                                  t < Duration.zero ? Duration.zero : t);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(Icons.replay_5,
                                  size: 24, color: fg),
                            ),
                          ),
                          // ── +5s ──
                          GestureDetector(
                            onTap: () {
                              final t = position + const Duration(seconds: 5);
                              _player.seek(t > total ? total : t);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(Icons.forward_5,
                                  size: 24, color: fg),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // ── vitesse ──
                          GestureDetector(
                            onTap: _toggleSpeed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.isMe
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : const Color(0xFFE85D75)
                                        .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _speed == 1.0 ? '1×' : '2×',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: fg,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Poll card ─────────────────────────────────────────────────────────────────

class _PollCard extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? currentUserId;
  final void Function(int)? onVote;
  final VoidCallback? onLongPress;

  const _PollCard({
    required this.message,
    required this.isMe,
    this.currentUserId,
    this.onVote,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(message.content) as Map<String, dynamic>;
    } catch (_) {
      return const SizedBox.shrink();
    }

    final question = data['question'] as String? ?? '';
    final options = List<String>.from(data['options'] as List? ?? []);
    final multipleChoice = data['multipleChoice'] as bool? ?? false;

    final userVoteKeys = <String>{};
    for (final key in message.reactions.keys) {
      if (message.reactions[key]?.contains(currentUserId) == true) {
        userVoteKeys.add(key);
      }
    }

    int totalVotes = 0;
    for (final voters in message.reactions.values) {
      totalVotes += voters.length;
    }

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: EdgeInsets.only(left: isMe ? 40 : 0, right: isMe ? 0 : 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête gradient
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE85D75), Color(0xFFC94060)],
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.poll_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            question,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (multipleChoice) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Choix multiples',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Options
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Column(
                  children: List.generate(options.length, (i) {
                    final key = i.toString();
                    final votes = message.reactions[key]?.length ?? 0;
                    final pct =
                        totalVotes > 0 ? votes / totalVotes : 0.0;
                    final isSelected = userVoteKeys.contains(key);

                    return GestureDetector(
                      onTap: () => onVote?.call(i),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE85D75).withValues(alpha: 0.08)
                              : const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFE85D75)
                                : AppColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  multipleChoice
                                      ? (isSelected
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank)
                                      : (isSelected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked),
                                  size: 15,
                                  color: isSelected
                                      ? const Color(0xFFE85D75)
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    options[i],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$votes',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            if (totalVotes > 0) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 4,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation(
                                    isSelected
                                        ? const Color(0xFFE85D75)
                                        : const Color(0xFFE85D75)
                                            .withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // Pied de carte
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  '$totalVotes vote${totalVotes != 1 ? 's' : ''}'
                  '${message.senderName != null ? ' · ${isMe ? 'Votre sondage' : message.senderName!}' : ''}'
                  '${message.editedAt != null ? ' · modifié' : ''}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit poll dialog ──────────────────────────────────────────────────────────

class _EditPollDialog extends StatefulWidget {
  final String question;
  final List<String> options;
  final bool multipleChoice;

  const _EditPollDialog({
    required this.question,
    required this.options,
    this.multipleChoice = false,
  });

  @override
  State<_EditPollDialog> createState() => _EditPollDialogState();
}

class _EditPollDialogState extends State<_EditPollDialog> {
  late final TextEditingController _questionController;
  late final List<TextEditingController> _optionControllers;
  late bool _multipleChoice;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.question);
    _optionControllers =
        widget.options.map((o) => TextEditingController(text: o)).toList();
    while (_optionControllers.length < 2) {
      _optionControllers.add(TextEditingController());
    }
    _multipleChoice = widget.multipleChoice;
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isValid {
    if (_questionController.text.trim().isEmpty) return false;
    return _optionControllers.where((c) => c.text.trim().isNotEmpty).length >=
        2;
  }

  void _addOption() {
    if (_optionControllers.length >= 5) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    final c = _optionControllers.removeAt(index);
    c.dispose();
    setState(() {});
  }

  void _submit() {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (question.isEmpty || options.length < 2) return;
    Navigator.of(context).pop({
      'question': question,
      'options': options,
      'multipleChoice': _multipleChoice,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.poll_outlined, color: Color(0xFFE85D75), size: 20),
          SizedBox(width: 8),
          Text('Modifier le sondage'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _questionController,
              autofocus: true,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'Posez votre question…',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            const Text(
              'Options',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(_optionControllers.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[i],
                        decoration: InputDecoration(
                          hintText: 'Option ${i + 1}',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_optionControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: AppColors.textSecondary,
                        onPressed: () => _removeOption(i),
                        padding: const EdgeInsets.only(left: 4),
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              );
            }),
            if (_optionControllers.length < 5)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter une option'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE85D75),
                  padding: EdgeInsets.zero,
                ),
              ),
            SwitchListTile(
              value: _multipleChoice,
              onChanged: (v) => setState(() => _multipleChoice = v),
              title: const Text(
                'Réponses multiples',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'Les participants peuvent voter pour plusieurs options',
                style: TextStyle(fontSize: 11),
              ),
              activeThumbColor: const Color(0xFFE85D75),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    color: Colors.orange,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Les votes existants seront réinitialisés.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _isValid ? _submit : null,
          child: const Text('Modifier'),
        ),
      ],
    );
  }
}

// ── Create poll dialog ────────────────────────────────────────────────────────

class _CreatePollDialog extends StatefulWidget {
  const _CreatePollDialog();

  @override
  State<_CreatePollDialog> createState() => _CreatePollDialogState();
}

class _CreatePollDialogState extends State<_CreatePollDialog> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _multipleChoice = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isValid {
    if (_questionController.text.trim().isEmpty) return false;
    final filled =
        _optionControllers.where((c) => c.text.trim().isNotEmpty).length;
    return filled >= 2;
  }

  void _addOption() {
    if (_optionControllers.length >= 5) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    final c = _optionControllers.removeAt(index);
    c.dispose();
    setState(() {});
  }

  void _submit() {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (question.isEmpty || options.length < 2) return;
    Navigator.of(context).pop({
      'question': question,
      'options': options,
      'multipleChoice': _multipleChoice,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.poll_outlined, color: Color(0xFFE85D75), size: 20),
          SizedBox(width: 8),
          Text('Créer un sondage'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _questionController,
              autofocus: true,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'Posez votre question…',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            const Text(
              'Options',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(_optionControllers.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[i],
                        decoration: InputDecoration(
                          hintText: 'Option ${i + 1}',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_optionControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: AppColors.textSecondary,
                        onPressed: () => _removeOption(i),
                        padding: const EdgeInsets.only(left: 4),
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              );
            }),
            if (_optionControllers.length < 5)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter une option'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE85D75),
                  padding: EdgeInsets.zero,
                ),
              ),
            SwitchListTile(
              value: _multipleChoice,
              onChanged: (v) => setState(() => _multipleChoice = v),
              title: const Text(
                'Réponses multiples',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'Les participants peuvent voter pour plusieurs options',
                style: TextStyle(fontSize: 11),
              ),
              activeThumbColor: const Color(0xFFE85D75),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _isValid ? _submit : null,
          child: const Text('Créer'),
        ),
      ],
    );
  }
}
