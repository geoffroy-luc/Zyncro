import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/l10n/generated/app_localizations.dart';

void main() {
  test(
    'textes migrés identiques aux libellés historiques (au caractère près)',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('fr'));
      expect(
        [
          l10n.tabHomeTitle,
          l10n.tabCalendarTitle,
          l10n.tabNotesTitle,
          l10n.tabExpensesTitle,
          l10n.tabChatTitle,
        ],
        ['Accueil', 'Calendrier', 'Notes', 'Dépenses', 'Chat'],
      );
      expect(
        [
          l10n.navHome,
          l10n.navCalendar,
          l10n.navNotes,
          l10n.navExpenses,
          l10n.navChat,
        ],
        ['Home', 'Calendar', 'Notes', 'Expenses', 'Chat'],
      );
      expect(
        l10n.updateAvailableBody('1.2.0'),
        'La version 1.2.0 est disponible. Voulez-vous mettre à jour ?',
      );
      expect(
        l10n.updateRequiredBody,
        "Cette version de Zyncro n'est plus supportée. Veuillez mettre à jour l'application pour continuer.",
      );
      expect(l10n.newNotificationsCount(3), '3 nouvelles notifications');
      expect(
        [l10n.updateLater, l10n.updateNow],
        ['Plus tard', 'Mettre à jour'],
      );
    },
  );
}
