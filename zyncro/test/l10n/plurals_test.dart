import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/l10n/generated/app_localizations.dart';

void main() {
  test('pluriels ICU = formules historiques (cas 0, 1, n)', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    for (final n in [0, 1, 2, 7]) {
      expect(l10n.commonMemberCount(n), '$n membre${n > 1 ? 's' : ''}');
      expect(l10n.notesMoreItems(n), '+ $n autre${n > 1 ? 's' : ''}');
      expect(l10n.chatPollVoteCount(n), '$n vote${n != 1 ? 's' : ''}');
    }
    expect(l10n.expensesPaidBy('Bob'), 'Payé par Bob');
    expect(l10n.expensesPaidByYou, 'Payé par vous');
    expect(
      l10n.groupsInvalidInviteLinkBody,
      "Ce lien d'invitation est invalide ou a expiré. Demande un nouveau "
      'lien à un membre du groupe.',
    );
  });
}
