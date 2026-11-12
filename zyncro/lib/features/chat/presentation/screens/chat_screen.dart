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

part 'chat_screen_composer.dart';
part 'chat_screen_message_actions.dart';
part 'chat_screen_recording.dart';
part 'chat_screen_media.dart';
part 'chat_screen_menus.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

const _quickEmojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];

bool _isSameGroup(Message older, Message newer) {
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

/// Champs et contrat commun des mixins de l'écran (parts chat_screen_composer.dart, chat_screen_message_actions.dart, chat_screen_recording.dart, chat_screen_media.dart, chat_screen_menus.dart).
abstract class _ChatScreenStateBase extends ConsumerState<ChatScreen> {
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

  // ── Implémentées par les mixins ──
  Future<void> _showCreatePoll();
  Future<void> _pickFromGallery();
  Future<void> _captureFromCamera({required bool video});
}

class _ChatScreenState extends _ChatScreenStateBase
    with
        _ChatComposer,
        _ChatMessageActions,
        _ChatRecording,
        _ChatMediaSending,
        _ChatActionMenus {
  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
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
