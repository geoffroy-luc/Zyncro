import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/app/router.dart';
import 'package:zyncro/core/notifications/notification_providers.dart';
import 'package:zyncro/design_system/context_extensions.dart';

/// Widget that shows a temporary in-app banner when a foreground message arrives.
/// Multiple messages arriving within 600 ms are grouped into one snackbar.
class NotificationBanner extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationBanner({super.key, required this.child});

  @override
  ConsumerState<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends ConsumerState<NotificationBanner> {
  final List<RemoteMessage> _pending = [];
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _enqueue(RemoteMessage message) {
    _pending.add(message);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 600), _flush);
  }

  void _flush() {
    if (!mounted || _pending.isEmpty) return;

    final messages = List<RemoteMessage>.from(_pending);
    _pending.clear();

    // Filtrer les messages dont on est déjà sur l'écran
    final currentPath = ref
        .read(routerProvider)
        .routeInformationProvider
        .value
        .uri
        .path;
    final visible = messages.where((m) {
      final screen = m.data['screen'] as String?;
      return screen == null || currentPath != '/$screen';
    }).toList();

    if (visible.isEmpty) return;

    final SnackBar snackBar;
    if (visible.length == 1) {
      final notif = visible.first.notification;
      if (notif == null) return;
      snackBar = SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notif.title != null)
              Text(
                notif.title!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            if (notif.body != null) Text(notif.body!),
          ],
        ),
      );
    } else {
      snackBar = SnackBar(
        content: Text(context.l10n.newNotificationsCount(visible.length)),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RemoteMessage?>(foregroundMessageProvider, (_, message) {
      if (message == null) return;
      if (message.notification == null) return;
      _enqueue(message);
    });

    return widget.child;
  }
}
