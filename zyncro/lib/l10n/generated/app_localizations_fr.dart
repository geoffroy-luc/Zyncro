// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get tabHomeTitle => 'Accueil';

  @override
  String get tabCalendarTitle => 'Calendrier';

  @override
  String get tabNotesTitle => 'Notes';

  @override
  String get tabExpensesTitle => 'Dépenses';

  @override
  String get tabChatTitle => 'Chat';

  @override
  String get navHome => 'Home';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navNotes => 'Notes';

  @override
  String get navExpenses => 'Expenses';

  @override
  String get navChat => 'Chat';

  @override
  String get updateRequiredTitle => 'Mise à jour requise';

  @override
  String get updateAvailableTitle => 'Mise à jour disponible';

  @override
  String get updateRequiredBody =>
      'Cette version de Zyncro n\'est plus supportée. Veuillez mettre à jour l\'application pour continuer.';

  @override
  String updateAvailableBody(String version) {
    return 'La version $version est disponible. Voulez-vous mettre à jour ?';
  }

  @override
  String get updateLater => 'Plus tard';

  @override
  String get updateNow => 'Mettre à jour';

  @override
  String newNotificationsCount(int count) {
    return '$count nouvelles notifications';
  }
}
