import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/app/notification_banner.dart';
import 'package:zyncro/app/router.dart';
import 'package:zyncro/core/app_update/app_update_service.dart';
import 'package:zyncro/core/logging/app_logger.dart';
import 'package:zyncro/core/notifications/local_notifications.dart';
import 'package:zyncro/core/notifications/notification_providers.dart';
import 'package:zyncro/core/theme/app_theme.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/chat/presentation/providers/share_provider.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/groups/presentation/providers/invite_link_provider.dart';

class ZyncroApp extends ConsumerStatefulWidget {
  const ZyncroApp({super.key});

  @override
  ConsumerState<ZyncroApp> createState() => _ZyncroAppState();
}

class _ZyncroAppState extends ConsumerState<ZyncroApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    ref.read(pushNotificationServiceProvider).onTap = _onNotificationTap;
    WidgetsBinding.instance.addObserver(this);
    // Run after the first frame so the GoRouter navigator is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  Future<void> _checkUpdate() async {
    final info = await ref.read(appUpdateServiceProvider).check();
    if (info == null || !mounted) return;

    // Use GoRouter's navigator key — it always has a valid context.
    final navKey = ref.read(rootNavigatorKeyProvider);
    final ctx = navKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    unawaited(
      showDialog<void>(
        context: ctx,
        barrierDismissible: !info.isMandatory,
        builder: (dialogCtx) => PopScope(
          canPop: !info.isMandatory,
          child: AlertDialog(
            title: Text(
              info.isMandatory
                  ? 'Mise à jour requise'
                  : 'Mise à jour disponible',
            ),
            content: Text(
              info.isMandatory
                  ? "Cette version de Zyncro n'est plus supportée. Veuillez mettre à jour l'application pour continuer."
                  : 'La version ${info.latestVersion} est disponible. Voulez-vous mettre à jour ?',
            ),
            actions: [
              if (!info.isMandatory)
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Plus tard'),
                ),
              TextButton(
                onPressed: () =>
                    ref.read(appUpdateServiceProvider).openStore(info.storeUrl),
                child: const Text('Mettre à jour'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ouverture d'une notification : sélectionne le groupe puis navigue vers
  /// l'onglet visé.
  Future<void> _onNotificationTap(String groupId, String? screen) async {
    final route = switch (screen) {
      'chat' => '/chat',
      'expenses' => '/expenses',
      'notes' => '/notes',
      'calendar' => '/calendar',
      _ => '/home',
    };
    await ref.read(selectedGroupIdProvider.notifier).select(groupId);

    // Double post-frame : le 1er frame laisse GoRouter traiter le refresh
    // déclenché par selectedGroupIdProvider, le 2e effectue la navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppLogger.info('Notif', 'navigating → $route');
        ref.read(routerProvider).go(route);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final inForeground = state == AppLifecycleState.resumed;
    ref.read(appInForegroundProvider.notifier).setForeground(inForeground);
    if (inForeground) {
      unawaited(LocalNotifications.dismissAll());
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Garde vivants : réception des partages entrants + raccourcis de partage
    // direct (groupes les plus actifs) synchronisés avec Android + réception
    // des liens d'invitation entrants (App Links / Universal Links).
    ref.watch(incomingShareProvider);
    ref.watch(shareShortcutsControllerProvider);
    ref.watch(inviteLinkProvider);

    // Initialize FCM when the user is authenticated
    ref.listen(authStateProvider, (_, next) {
      final user = next.asData?.value;
      if (user != null) {
        unawaited(
          ref.read(pushNotificationServiceProvider).initialize(user.uid),
        );
      }
    });

    // Dismiss OS notifications when a group is opened + note l'activité du groupe
    ref.listen(selectedGroupIdProvider, (_, next) {
      final groupId = next.asData?.value;
      if (groupId != null) {
        unawaited(LocalNotifications.dismissAll());
        unawaited(
          ref
              .read(shareShortcutsControllerProvider.notifier)
              .recordInteraction(groupId),
        );
      }
    });

    return MaterialApp.router(
      title: 'Zyncro',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      locale: const Locale('fr', 'FR'),
      builder: (context, child) =>
          NotificationBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
