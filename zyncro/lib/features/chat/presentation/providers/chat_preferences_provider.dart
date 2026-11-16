import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/features/chat/data/services/chat_preferences.dart';

final chatPreferencesProvider = Provider<ChatPreferences>(
  (_) => const ChatPreferences(),
);

/// Afficher l'activité de l'espace dans le chat (réglage de l'appareil).
class ChatActivityVisibleNotifier extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_load());
    return true;
  }

  Future<void> _load() async {
    final visible = await ref.read(chatPreferencesProvider).isActivityVisible();
    if (visible != state) state = visible;
  }

  Future<void> set({required bool visible}) async {
    state = visible;
    await ref.read(chatPreferencesProvider).setActivityVisible(visible);
  }
}

final chatActivityVisibleProvider =
    NotifierProvider<ChatActivityVisibleNotifier, bool>(
      ChatActivityVisibleNotifier.new,
    );
