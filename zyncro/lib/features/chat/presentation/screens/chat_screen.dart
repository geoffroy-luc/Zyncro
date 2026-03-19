import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/message.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../domain/repositories/i_messages_repository.dart';
import '../providers/messages_provider.dart';

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
      userName: user.displayName ?? user.email ?? 'Anonyme',
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
            senderName: user.displayName ?? user.email ?? 'Anonyme',
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
                            ? const Color(0xFF4F7CFF).withValues(alpha: 0.15)
                            : const Color(0xFFF7F9FC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasReacted
                              ? const Color(0xFF4F7CFF)
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
            if (isMe && message.type != MessageType.poll)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier'),
                onTap: () => Navigator.of(ctx).pop('edit'),
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
    if (action == 'delete') {
      await _deleteMessage(message);
    }
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
    await ref.read(messagesRepositoryProvider).toggleReaction(
          groupId: groupId,
          messageId: message.id,
          emoji: key,
          userId: currentUser.uid,
          hasReacted: hasVoted,
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
          senderName: user.displayName ?? user.email ?? 'Anonyme',
          question: result['question'] as String,
          options: List<String>.from(result['options'] as List),
        );

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final group = ref.watch(selectedGroupProvider);
    // .value renvoie le dernier UID connu même si le provider repasse
    // brièvement en AsyncLoading (ex: rebuild déclenché par messagesProvider)
    final currentUid = ref.watch(
      authStateProvider.select((s) => s.value?.uid),
    );
    final messagesAsync = ref.watch(messagesProvider);

    if (currentUid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(24, topPad + 12, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4F7CFF), Color(0xFF315FEA)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F7CFF).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      group?.emoji ??
                          (group?.name.substring(0, 2).toUpperCase() ?? '??'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group?.name ?? '',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        '${group?.memberIds.length ?? 0} membre${(group?.memberIds.length ?? 0) > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

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
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: isFirstInGroup ? 10 : 2,
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
                              ? (i) => _votePoll(msg, i)
                              : null,
                        ),
                      ),
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
                      color: const Color(0xFF4F7CFF),
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
                            color: Color(0xFF4F7CFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _replyingTo!.content,
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
            child: Row(
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
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF4F7CFF), Color(0xFF315FEA)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F7CFF).withValues(alpha: 0.25),
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
    this.currentUserId,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onVote,
  });

  Color _avatarColor(String uid) {
    final colors = [
      const Color(0xFF4F7CFF),
      const Color(0xFF2BB8A5),
      const Color(0xFFFFB86B),
      const Color(0xFFE85D75),
      const Color(0xFF9B59B6),
      const Color(0xFF27AE60),
    ];
    return colors[uid.hashCode.abs() % colors.length];
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4F7CFF), Color(0xFF315FEA)],
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
                  Text(
                    message.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
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
    final avatarColor = _avatarColor(message.senderId ?? '');

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
              message.senderName ?? '',
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
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: avatarColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials(message.senderName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: radius,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.replyToContent != null)
                          _ReplyPreview(
                            senderName: message.replyToSenderName,
                            content: message.replyToContent!,
                            isMe: false,
                          ),
                        Text(
                          message.content,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
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

class _ReactionsRow extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final String? currentUserId;

  const _ReactionsRow({required this.reactions, this.currentUserId});

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

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isMine
                ? const Color(0xFF4F7CFF).withValues(alpha: 0.15)
                : const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMine
                  ? const Color(0xFF4F7CFF).withValues(alpha: 0.4)
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
                      ? const Color(0xFF315FEA)
                      : AppColors.textSecondary,
                ),
              ),
            ],
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
                : const Color(0xFF4F7CFF),
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
                    : const Color(0xFF4F7CFF),
              ),
            ),
          Text(
            content,
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
                    color: Color(0xFF4F7CFF),
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

    String? userVoteKey;
    for (final key in message.reactions.keys) {
      if (message.reactions[key]?.contains(currentUserId) == true) {
        userVoteKey = key;
        break;
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
                    colors: [Color(0xFF4F7CFF), Color(0xFF315FEA)],
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),
                child: Row(
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
                    final isSelected = userVoteKey == key;

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
                              ? const Color(0xFF4F7CFF).withValues(alpha: 0.08)
                              : const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4F7CFF)
                                : AppColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 15,
                                  color: isSelected
                                      ? const Color(0xFF4F7CFF)
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
                                        ? const Color(0xFF4F7CFF)
                                        : const Color(0xFF4F7CFF)
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
                  '${message.senderName != null ? ' · ${isMe ? 'Votre sondage' : message.senderName!}' : ''}',
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
    Navigator.of(context).pop({'question': question, 'options': options});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.poll_outlined, color: Color(0xFF4F7CFF), size: 20),
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
                  foregroundColor: const Color(0xFF4F7CFF),
                  padding: EdgeInsets.zero,
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
          child: const Text('Créer'),
        ),
      ],
    );
  }
}
