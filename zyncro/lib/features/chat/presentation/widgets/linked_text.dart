import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/chat/presentation/widgets/message_bubble.dart';

// ── Texte avec liens cliquables ──────────────────────────────────────────────

class LinkedText extends StatefulWidget {
  final String text;
  final bool isMe;

  const LinkedText({super.key, required this.text, required this.isMe});

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
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
    final matches = MessageBubble.urlRegex.allMatches(text).toList();
    final textColor = isMe ? Colors.white : context.colors.textPrimary;
    final linkColor = isMe ? Colors.white : const Color(0xFF1D6AE5);
    final textStyle = TextStyle(color: textColor, fontSize: 14, height: 1.4);

    if (matches.isEmpty) {
      return Text(text, style: textStyle);
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: textStyle,
          ),
        );
      }
      final url = MessageBubble.cleanUrl(match.group(0)!);
      final recognizer = TapGestureRecognizer()
        ..onTap = () => MessageBubble.openUrl(url);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          style: textStyle.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
          recognizer: recognizer,
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: textStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
