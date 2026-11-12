import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/core/media/media_providers.dart';
import 'package:zyncro/core/media/media_source.dart';
import 'package:zyncro/core/media/voice_recorder.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/core/utils/duration_format.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';
import 'package:zyncro/features/chat/domain/repositories/messages_repository.dart';
import 'package:zyncro/features/chat/domain/typing_throttle.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/chat/presentation/screens/media_picker_screen.dart';
import 'package:zyncro/features/chat/presentation/widgets/chat_search_bar.dart';
import 'package:zyncro/features/chat/presentation/widgets/composer_context_bar.dart';
import 'package:zyncro/features/chat/presentation/widgets/create_poll_dialog.dart';
import 'package:zyncro/features/chat/presentation/widgets/edit_poll_dialog.dart';
import 'package:zyncro/features/chat/presentation/widgets/gradient_circle_button.dart';
import 'package:zyncro/features/chat/presentation/widgets/media_downloader.dart';
import 'package:zyncro/features/chat/presentation/widgets/message_bubble.dart';
import 'package:zyncro/features/chat/presentation/widgets/recording_bar.dart';
import 'package:zyncro/features/chat/presentation/widgets/reply_kind_label.dart';
import 'package:zyncro/features/chat/presentation/widgets/seen_by_row.dart';
import 'package:zyncro/features/chat/presentation/widgets/swipe_to_reply.dart';
import 'package:zyncro/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:zyncro/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:zyncro/features/groups/domain/entities/group_member.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';

part 'chat_screen_composer.dart';
part 'chat_screen_media.dart';
part 'chat_screen_menus.dart';
part 'chat_screen_message_actions.dart';
part 'chat_screen_recording.dart';
part 'chat_screen_sections.dart';

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

/// Champs et contrat commun des mixins de l'écran (parts chat_screen_composer.dart, chat_screen_message_actions.dart, chat_screen_recording.dart, chat_screen_media.dart, chat_screen_menus.dart, chat_screen_sections.dart).
abstract class _ChatScreenStateBase extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();
  bool _sending = false;
  Timer? _typingTimer;
  final _typingThrottle = TypingThrottle();
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

  late final VoiceRecorder _recorder;
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
        _ChatActionMenus,
        _ChatScreenSections {
  @override
  void initState() {
    super.initState();
    _recorder = ref.read(voiceRecorderFactoryProvider)();
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

    _listenReadReceipts();
    _listenGroupChange();

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
            Image.network(
              bgValue,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            child,
          ],
        );
      }
      return child;
    }

    final bgColor = bgType == 'color' && bgValue != null
        ? (tryHexToColor(bgValue) ?? context.colors.background)
        : context.colors.background;

    return Scaffold(
      backgroundColor: bgColor,
      body: buildBackground(
        SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  if (_showSearch)
                    ChatSearchBar(
                      onChanged: (v) => setState(() => _search = v),
                      onClose: () => setState(() {
                        _showSearch = false;
                        _search = '';
                      }),
                    ),
                  // ── Messages ────────────────────────────────────────────────
                  Expanded(
                    child: chatAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) =>
                          Center(child: Text(context.l10n.chatErreur(e))),
                      data: (chatState) => _buildMessageList(
                        chatState,
                        currentUid,
                        members,
                        bgType,
                      ),
                    ),
                  ),

                  // ── Typing indicator ────────────────────────────────────────
                  TypingIndicator(
                    typingUsers: ref.watch(typingProvider).asData?.value ?? [],
                  ),

                  // ── Edit bar ────────────────────────────────────────────────
                  if (_editingMessage != null)
                    ComposerContextBar(
                      onClose: () => setState(() {
                        _editingMessage = null;
                        _controller.clear();
                      }),
                      child: Text(
                        context.l10n.chatModifierLeMessage,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // ── Reply bar ───────────────────────────────────────────────
                  if (_replyingTo != null)
                    ComposerContextBar(
                      onClose: () => setState(() => _replyingTo = null),
                      child: _buildReplyPreview(_replyingTo!),
                    ),

                  _buildInputBar(),
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
