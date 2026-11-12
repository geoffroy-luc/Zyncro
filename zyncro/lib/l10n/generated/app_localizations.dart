import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('fr')];

  /// Titre de l'onglet dans la barre du haut du shell
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get tabHomeTitle;

  /// No description provided for @tabCalendarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier'**
  String get tabCalendarTitle;

  /// No description provided for @tabNotesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notes'**
  String get tabNotesTitle;

  /// No description provided for @tabExpensesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses'**
  String get tabExpensesTitle;

  /// No description provided for @tabChatTitle.
  ///
  /// In fr, this message translates to:
  /// **'Chat'**
  String get tabChatTitle;

  /// Libellé de la barre de navigation du bas (anglais historique, conservé à l'identique — Y-03)
  ///
  /// In fr, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCalendar.
  ///
  /// In fr, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navNotes.
  ///
  /// In fr, this message translates to:
  /// **'Notes'**
  String get navNotes;

  /// No description provided for @navExpenses.
  ///
  /// In fr, this message translates to:
  /// **'Expenses'**
  String get navExpenses;

  /// No description provided for @navChat.
  ///
  /// In fr, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour requise'**
  String get updateRequiredTitle;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour disponible'**
  String get updateAvailableTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette version de Zyncro n\'est plus supportée. Veuillez mettre à jour l\'application pour continuer.'**
  String get updateRequiredBody;

  /// No description provided for @updateAvailableBody.
  ///
  /// In fr, this message translates to:
  /// **'La version {version} est disponible. Voulez-vous mettre à jour ?'**
  String updateAvailableBody(String version);

  /// No description provided for @updateLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get updateLater;

  /// No description provided for @updateNow.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour'**
  String get updateNow;

  /// Bandeau in-app quand plusieurs notifications arrivent ensemble (toujours ≥ 2)
  ///
  /// In fr, this message translates to:
  /// **'{count} nouvelles notifications'**
  String newNotificationsCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
