import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/notification_service.dart';
import '../core/services/update_service.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/chat/presentation/providers/messages_provider.dart';
import 'router.dart';

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
    WidgetsBinding.instance.addObserver(this);
    // Run after the first frame so the GoRouter navigator is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  Future<void> _checkUpdate() async {
    final info = await UpdateService.check();
    if (info == null || !mounted) return;

    // Use GoRouter's navigator key — it always has a valid context.
    final navKey = ref.read(rootNavigatorKeyProvider);
    final ctx = navKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

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
              onPressed: () => UpdateService.openStore(info.storeUrl),
              child: const Text('Mettre à jour'),
            ),
          ],
        ),
      ),
    );
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
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Initialize FCM when the user is authenticated
    ref.listen(authStateProvider, (_, next) {
      final user = next.asData?.value;
      if (user != null) {
        NotificationService.initialize(user.uid, ref);
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
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'FR'),
      builder: (context, child) =>
          NotificationBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
