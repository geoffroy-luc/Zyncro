import 'package:share_plus/share_plus.dart';

import '../constants/invite.dart';

/// Ouvre la feuille de partage native (WhatsApp, SMS, mail…) avec un lien
/// d'invitation pré-rempli pour le groupe identifié par [code].
Future<void> shareInviteLink({
  required String code,
  String? groupName,
}) async {
  final link = InviteLink.forCode(code);
  final name = (groupName != null && groupName.trim().isNotEmpty)
      ? ' « ${groupName.trim()} »'
      : '';
  final text = 'Rejoins mon espace$name sur Zyncro 👥\n$link';
  await SharePlus.instance.share(
    ShareParams(text: text, subject: 'Invitation Zyncro'),
  );
}
