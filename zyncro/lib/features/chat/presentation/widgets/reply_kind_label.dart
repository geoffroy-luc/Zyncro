import 'package:flutter/widgets.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/chat/domain/reply_kind.dart';

/// Libellé d'une citation : le texte, ou la nature du média cité.
String replyLabel(BuildContext context, String content) =>
    switch (replyKindOf(content)) {
      ReplyKind.text => content,
      ReplyKind.photo => context.l10n.chatReplyPhoto,
      ReplyKind.video => context.l10n.chatReplyVideo,
      ReplyKind.album => context.l10n.chatReplyAlbum,
      ReplyKind.audio => context.l10n.chatReplyAudio,
      ReplyKind.poll => context.l10n.chatReplyPoll,
    };
