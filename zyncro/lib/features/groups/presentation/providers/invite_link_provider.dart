import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/invite.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Écoute les liens d'invitation entrants (App Links / Universal Links /
/// schéma `zyncro://`) et navigue vers l'écran de confirmation `/i/CODE`.
///
/// Le code en attente est conservé dans l'état : si le lien est ouvert alors
/// que l'utilisateur n'est pas connecté, on le rejoue une fois la connexion
/// établie (le `redirect` du routeur s'appuie aussi dessus).
class InviteLinkNotifier extends Notifier<String?> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialHandled = false;

  @override
  String? build() {
    _sub = _appLinks.uriLinkStream.listen(_onUri, onError: (_) {});
    ref.onDispose(() => _sub?.cancel());

    // Démarrage à froid : traite le lien initial une seule fois.
    if (!_initialHandled) {
      _initialHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final initial = await _appLinks.getInitialLink();
        if (initial != null) _onUri(initial);
      });
    }

    // Lien ouvert hors connexion → rejoué dès que l'utilisateur se connecte.
    ref.listen(authStateProvider, (_, next) {
      final code = state;
      if (next.asData?.value != null && code != null) {
        _navigate(code);
      }
    });

    return null;
  }

  void _onUri(Uri uri) {
    final code = InviteLink.codeFromUri(uri);
    if (code == null) return;
    state = code;
    _navigate(code);
  }

  void _navigate(String code) {
    ref.read(routerProvider).go('/${InviteLink.pathPrefix}/$code');
  }

  /// Efface le code en attente (après adhésion ou annulation).
  void clear() => state = null;
}

final inviteLinkProvider = NotifierProvider<InviteLinkNotifier, String?>(
  InviteLinkNotifier.new,
);
