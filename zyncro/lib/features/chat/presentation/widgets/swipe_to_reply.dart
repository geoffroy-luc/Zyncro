import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Swipe to reply ────────────────────────────────────────────────────────────

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;
  final bool isMe;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.isMe,
    this.onReply,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
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
      unawaited(HapticFeedback.lightImpact());
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
    unawaited(_controller.forward(from: 0));
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
                  child: Align(
                    child: Icon(
                      Icons.reply_rounded,
                      color: Theme.of(context).colorScheme.primary,
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
