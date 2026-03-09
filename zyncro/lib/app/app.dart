import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import 'router.dart';

class ZyncroApp extends ConsumerWidget {
  const ZyncroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
