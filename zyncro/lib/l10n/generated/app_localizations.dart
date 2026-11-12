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

  /// No description provided for @authEmailDeReinitialisationEnvoye.
  ///
  /// In fr, this message translates to:
  /// **'Email de réinitialisation envoyé !'**
  String get authEmailDeReinitialisationEnvoye;

  /// No description provided for @authZyncro.
  ///
  /// In fr, this message translates to:
  /// **'Zyncro'**
  String get authZyncro;

  /// No description provided for @authRetrouveTonEspacePartage.
  ///
  /// In fr, this message translates to:
  /// **'Retrouve ton espace partagé'**
  String get authRetrouveTonEspacePartage;

  /// No description provided for @authMotDePasseOublie.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get authMotDePasseOublie;

  /// No description provided for @authSeConnecter.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get authSeConnecter;

  /// No description provided for @authOu.
  ///
  /// In fr, this message translates to:
  /// **'ou'**
  String get authOu;

  /// No description provided for @authContinuerAvecGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get authContinuerAvecGoogle;

  /// No description provided for @authContinuerAvecApple.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Apple'**
  String get authContinuerAvecApple;

  /// No description provided for @authContinuerSansCompte.
  ///
  /// In fr, this message translates to:
  /// **'Continuer sans compte'**
  String get authContinuerSansCompte;

  /// No description provided for @authPasEncoreDeCompteS.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ? S\'inscrire'**
  String get authPasEncoreDeCompteS;

  /// No description provided for @authEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authMotDePasse.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get authMotDePasse;

  /// No description provided for @authModifierLePseudo.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le pseudo'**
  String get authModifierLePseudo;

  /// No description provided for @authAnnuler.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get authAnnuler;

  /// No description provided for @authEnregistrer.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get authEnregistrer;

  /// No description provided for @authPrendreUnePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get authPrendreUnePhoto;

  /// No description provided for @authChoisirDepuisLaGalerie.
  ///
  /// In fr, this message translates to:
  /// **'Choisir depuis la galerie'**
  String get authChoisirDepuisLaGalerie;

  /// No description provided for @authReinitialiserAvecLaPhotoGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser avec la photo Google/Apple'**
  String get authReinitialiserAvecLaPhotoGoogle;

  /// No description provided for @authErreur.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {p0}'**
  String authErreur(Object p0);

  /// No description provided for @authSeDeconnecter.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get authSeDeconnecter;

  /// No description provided for @authConfirmesTuLaDeconnexion.
  ///
  /// In fr, this message translates to:
  /// **'Confirmes-tu la déconnexion ?'**
  String get authConfirmesTuLaDeconnexion;

  /// No description provided for @authDeconnecter.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter'**
  String get authDeconnecter;

  /// No description provided for @authSupprimerLeCompte.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le compte'**
  String get authSupprimerLeCompte;

  /// No description provided for @authCetteActionEstIrreversibleTon.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Ton compte et toutes tes données seront définitivement supprimés.'**
  String get authCetteActionEstIrreversibleTon;

  /// No description provided for @authSupprimer.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get authSupprimer;

  /// No description provided for @authMonProfil.
  ///
  /// In fr, this message translates to:
  /// **'Mon profil'**
  String get authMonProfil;

  /// No description provided for @authPseudo.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo'**
  String get authPseudo;

  /// No description provided for @authAfficherMaPhotoDeProfil.
  ///
  /// In fr, this message translates to:
  /// **'Afficher ma photo de profil'**
  String get authAfficherMaPhotoDeProfil;

  /// No description provided for @authNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get authNotifications;

  /// No description provided for @authInformations.
  ///
  /// In fr, this message translates to:
  /// **'Informations'**
  String get authInformations;

  /// No description provided for @authPreferences.
  ///
  /// In fr, this message translates to:
  /// **'Préférences'**
  String get authPreferences;

  /// No description provided for @authCompte.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get authCompte;

  /// No description provided for @authCreerUnCompte.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get authCreerUnCompte;

  /// No description provided for @authRejoinsOuCreeTonEspace.
  ///
  /// In fr, this message translates to:
  /// **'Rejoins ou crée ton espace partagé'**
  String get authRejoinsOuCreeTonEspace;

  /// No description provided for @authSInscrire.
  ///
  /// In fr, this message translates to:
  /// **'S\'inscrire'**
  String get authSInscrire;

  /// No description provided for @authDejaUnCompteSeConnecter.
  ///
  /// In fr, this message translates to:
  /// **'Déjà un compte ? Se connecter'**
  String get authDejaUnCompteSeConnecter;

  /// No description provided for @authPrenomOuPseudo.
  ///
  /// In fr, this message translates to:
  /// **'Prénom ou pseudo'**
  String get authPrenomOuPseudo;

  /// No description provided for @authConfirmerLeMotDePasse.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get authConfirmerLeMotDePasse;

  /// No description provided for @authG.
  ///
  /// In fr, this message translates to:
  /// **'G'**
  String get authG;

  /// No description provided for @authEntreUnPseudoPourEtre.
  ///
  /// In fr, this message translates to:
  /// **'Entre un pseudo pour être identifié dans ton groupe.'**
  String get authEntreUnPseudoPourEtre;

  /// No description provided for @authContinuer.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get authContinuer;

  /// No description provided for @calendarAucunEvenement.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement'**
  String get calendarAucunEvenement;

  /// No description provided for @calendarAjouterUnEvenement.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un événement'**
  String get calendarAjouterUnEvenement;

  /// No description provided for @calendarRechercher.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher...'**
  String get calendarRechercher;

  /// No description provided for @calendarMois.
  ///
  /// In fr, this message translates to:
  /// **'Mois'**
  String get calendarMois;

  /// No description provided for @calendarAgenda.
  ///
  /// In fr, this message translates to:
  /// **'Agenda'**
  String get calendarAgenda;

  /// No description provided for @calendarFiltres.
  ///
  /// In fr, this message translates to:
  /// **'Filtres'**
  String get calendarFiltres;

  /// No description provided for @calendarReinitialiser.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get calendarReinitialiser;

  /// No description provided for @calendarParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Participants'**
  String get calendarParticipants;

  /// No description provided for @calendarRecurrentsUniquement.
  ///
  /// In fr, this message translates to:
  /// **'Récurrents uniquement'**
  String get calendarRecurrentsUniquement;

  /// No description provided for @calendarAppliquer.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get calendarAppliquer;

  /// No description provided for @calendarParametresCalendrier.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres Calendrier'**
  String get calendarParametresCalendrier;

  /// No description provided for @calendarBande.
  ///
  /// In fr, this message translates to:
  /// **'Bande'**
  String get calendarBande;

  /// No description provided for @calendarPoint.
  ///
  /// In fr, this message translates to:
  /// **'Point'**
  String get calendarPoint;

  /// No description provided for @calendarApparence.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get calendarApparence;

  /// No description provided for @calendarAffichage.
  ///
  /// In fr, this message translates to:
  /// **'Affichage'**
  String get calendarAffichage;

  /// No description provided for @calendarSupprimerLEvenement.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'événement'**
  String get calendarSupprimerLEvenement;

  /// No description provided for @calendarCetteActionEstIrreversible.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible.'**
  String get calendarCetteActionEstIrreversible;

  /// No description provided for @calendarAnnuler.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get calendarAnnuler;

  /// No description provided for @calendarSupprimer.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get calendarSupprimer;

  /// No description provided for @calendarPermissionRefusee.
  ///
  /// In fr, this message translates to:
  /// **'Permission refusée'**
  String get calendarPermissionRefusee;

  /// No description provided for @calendarLaDateDeFinDoit.
  ///
  /// In fr, this message translates to:
  /// **'La date de fin doit être après la date de début'**
  String get calendarLaDateDeFinDoit;

  /// No description provided for @calendarErreur.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {p0}'**
  String calendarErreur(Object p0);

  /// No description provided for @calendarRepetition.
  ///
  /// In fr, this message translates to:
  /// **'Répétition'**
  String get calendarRepetition;

  /// No description provided for @calendarAucune.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get calendarAucune;

  /// No description provided for @calendarFinDeLaRepetition.
  ///
  /// In fr, this message translates to:
  /// **'Fin de la répétition'**
  String get calendarFinDeLaRepetition;

  /// No description provided for @calendarToujours.
  ///
  /// In fr, this message translates to:
  /// **'Toujours'**
  String get calendarToujours;

  /// No description provided for @calendarNombreDeFois.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de fois :'**
  String get calendarNombreDeFois;

  /// No description provided for @calendarNombreDeFois2.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de fois'**
  String get calendarNombreDeFois2;

  /// No description provided for @calendarJusquAu.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'au :'**
  String get calendarJusquAu;

  /// No description provided for @calendarJusquAu2.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'au'**
  String get calendarJusquAu2;

  /// No description provided for @calendarConfirmer.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get calendarConfirmer;

  /// No description provided for @calendarRappel.
  ///
  /// In fr, this message translates to:
  /// **'Rappel'**
  String get calendarRappel;

  /// No description provided for @calendarPersonnalise.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisé…'**
  String get calendarPersonnalise;

  /// No description provided for @calendarRappelPersonnalise.
  ///
  /// In fr, this message translates to:
  /// **'Rappel personnalisé'**
  String get calendarRappelPersonnalise;

  /// No description provided for @calendarMin.
  ///
  /// In fr, this message translates to:
  /// **'min'**
  String get calendarMin;

  /// No description provided for @calendarH.
  ///
  /// In fr, this message translates to:
  /// **'h'**
  String get calendarH;

  /// No description provided for @calendarJ.
  ///
  /// In fr, this message translates to:
  /// **'j'**
  String get calendarJ;

  /// No description provided for @calendarOk.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get calendarOk;

  /// No description provided for @calendarCouleur.
  ///
  /// In fr, this message translates to:
  /// **'Couleur'**
  String get calendarCouleur;

  /// No description provided for @calendarAjouterUneHeureDeFin.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une heure de fin'**
  String get calendarAjouterUneHeureDeFin;

  /// No description provided for @calendarTitre.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get calendarTitre;

  /// No description provided for @calendarLieuOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'Lieu (optionnel)'**
  String get calendarLieuOptionnel;

  /// No description provided for @calendarDescriptionOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'Description (optionnel)'**
  String get calendarDescriptionOptionnel;

  /// No description provided for @calendarDebut.
  ///
  /// In fr, this message translates to:
  /// **'Début'**
  String get calendarDebut;

  /// No description provided for @calendarFin.
  ///
  /// In fr, this message translates to:
  /// **'Fin'**
  String get calendarFin;

  /// No description provided for @chatErreur.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {p0}'**
  String chatErreur(Object p0);

  /// No description provided for @chatAucunMessageSoyezLePremier.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message. Soyez le premier !'**
  String get chatAucunMessageSoyezLePremier;

  /// No description provided for @chatReplyPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get chatReplyPhoto;

  /// No description provided for @chatReplyVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get chatReplyVideo;

  /// No description provided for @chatReplyAlbum.
  ///
  /// In fr, this message translates to:
  /// **'Album'**
  String get chatReplyAlbum;

  /// No description provided for @chatReplyAudio.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get chatReplyAudio;

  /// No description provided for @chatReplyPoll.
  ///
  /// In fr, this message translates to:
  /// **'Sondage'**
  String get chatReplyPoll;

  /// No description provided for @chatAucunResultat.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message ne correspond à la recherche.'**
  String get chatAucunResultat;

  /// No description provided for @chatMediasEnregistres.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun média enregistré} =1{1 média enregistré dans la galerie} other{{count} médias enregistrés dans la galerie}}'**
  String chatMediasEnregistres(int count);

  /// No description provided for @chatEchecEnvoiMessage.
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'envoi du message.'**
  String get chatEchecEnvoiMessage;

  /// No description provided for @chatModifierLeMessage.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le message'**
  String get chatModifierLeMessage;

  /// No description provided for @chatEnregistrement.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement…'**
  String get chatEnregistrement;

  /// No description provided for @chatRechercherDansLeChat.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher dans le chat...'**
  String get chatRechercherDansLeChat;

  /// No description provided for @chatEcrireUnMessage.
  ///
  /// In fr, this message translates to:
  /// **'Écrire un message...'**
  String get chatEcrireUnMessage;

  /// No description provided for @chatMessageIntrouvable.
  ///
  /// In fr, this message translates to:
  /// **'Message introuvable'**
  String get chatMessageIntrouvable;

  /// No description provided for @chatImpossibleDeModifierLeMessage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de modifier le message.'**
  String get chatImpossibleDeModifierLeMessage;

  /// No description provided for @chatErreurEnvoiMedia.
  ///
  /// In fr, this message translates to:
  /// **'Erreur envoi média : {p0}'**
  String chatErreurEnvoiMedia(Object p0);

  /// No description provided for @chatRepondre.
  ///
  /// In fr, this message translates to:
  /// **'Répondre'**
  String get chatRepondre;

  /// No description provided for @chatCopier.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get chatCopier;

  /// No description provided for @chatModifier.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get chatModifier;

  /// No description provided for @chatModifierLeSondage.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le sondage'**
  String get chatModifierLeSondage;

  /// No description provided for @chatTelecharger.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get chatTelecharger;

  /// No description provided for @chatSupprimer.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get chatSupprimer;

  /// No description provided for @chatMessageCopie.
  ///
  /// In fr, this message translates to:
  /// **'Message copié'**
  String get chatMessageCopie;

  /// No description provided for @chatImpossibleDeModifierLeSondage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de modifier le sondage.'**
  String get chatImpossibleDeModifierLeSondage;

  /// No description provided for @chatSupprimerLeMessage.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le message'**
  String get chatSupprimerLeMessage;

  /// No description provided for @chatCeMessageSeraSupprimeDefinitivement.
  ///
  /// In fr, this message translates to:
  /// **'Ce message sera supprimé définitivement.'**
  String get chatCeMessageSeraSupprimeDefinitivement;

  /// No description provided for @chatAnnuler.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get chatAnnuler;

  /// No description provided for @chatImpossibleDeSupprimerLeMessage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de supprimer le message.'**
  String get chatImpossibleDeSupprimerLeMessage;

  /// No description provided for @chatPermissionMicrophoneRefusee.
  ///
  /// In fr, this message translates to:
  /// **'Permission microphone refusée.'**
  String get chatPermissionMicrophoneRefusee;

  /// No description provided for @chatAudioError.
  ///
  /// In fr, this message translates to:
  /// **'Audio error: {p0}'**
  String chatAudioError(Object p0);

  /// No description provided for @chatPrendreUnePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get chatPrendreUnePhoto;

  /// No description provided for @chatChoisirDepuisLaGalerie.
  ///
  /// In fr, this message translates to:
  /// **'Choisir depuis la galerie'**
  String get chatChoisirDepuisLaGalerie;

  /// No description provided for @chatErreur2.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {p0}'**
  String chatErreur2(Object p0);

  /// No description provided for @chatParametresChat.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres Chat'**
  String get chatParametresChat;

  /// No description provided for @chatAucun.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get chatAucun;

  /// No description provided for @chatCouleur.
  ///
  /// In fr, this message translates to:
  /// **'Couleur'**
  String get chatCouleur;

  /// No description provided for @chatImage.
  ///
  /// In fr, this message translates to:
  /// **'Image'**
  String get chatImage;

  /// No description provided for @chatApparence.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get chatApparence;

  /// No description provided for @chatCouleurDuTheme.
  ///
  /// In fr, this message translates to:
  /// **'Couleur du thème'**
  String get chatCouleurDuTheme;

  /// No description provided for @chatBackgroundDuChat.
  ///
  /// In fr, this message translates to:
  /// **'Background du chat'**
  String get chatBackgroundDuChat;

  /// No description provided for @chatCouleurDuFond.
  ///
  /// In fr, this message translates to:
  /// **'Couleur du fond'**
  String get chatCouleurDuFond;

  /// No description provided for @chatChangerLImage.
  ///
  /// In fr, this message translates to:
  /// **'Changer l\'image'**
  String get chatChangerLImage;

  /// No description provided for @chatPhotosVideosPartagees.
  ///
  /// In fr, this message translates to:
  /// **'Photos & vidéos partagées'**
  String get chatPhotosVideosPartagees;

  /// No description provided for @chatVoirTousLesMediasDu.
  ///
  /// In fr, this message translates to:
  /// **'Voir tous les médias du groupe'**
  String get chatVoirTousLesMediasDu;

  /// No description provided for @chatMediasPartages.
  ///
  /// In fr, this message translates to:
  /// **'Médias partagés'**
  String get chatMediasPartages;

  /// No description provided for @chatAucunMediaPartage.
  ///
  /// In fr, this message translates to:
  /// **'Aucun média partagé'**
  String get chatAucunMediaPartage;

  /// No description provided for @chatEnvoyer.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer ({p0})'**
  String chatEnvoyer(Object p0);

  /// No description provided for @chatAccesALaGalerieRefuse.
  ///
  /// In fr, this message translates to:
  /// **'Accès à la galerie refusé'**
  String get chatAccesALaGalerieRefuse;

  /// No description provided for @chatOuvrirLesReglages.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages'**
  String get chatOuvrirLesReglages;

  /// No description provided for @chatAccesLimiteACertainesPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Accès limité à certaines photos'**
  String get chatAccesLimiteACertainesPhotos;

  /// No description provided for @chatToutAutoriser.
  ///
  /// In fr, this message translates to:
  /// **'Tout autoriser'**
  String get chatToutAutoriser;

  /// No description provided for @chatAucunMedia.
  ///
  /// In fr, this message translates to:
  /// **'Aucun média'**
  String get chatAucunMedia;

  /// No description provided for @chatImageEnregistreeDansLaGalerie.
  ///
  /// In fr, this message translates to:
  /// **'Image enregistrée dans la galerie'**
  String get chatImageEnregistreeDansLaGalerie;

  /// No description provided for @chatErreurTelechargement.
  ///
  /// In fr, this message translates to:
  /// **'Erreur téléchargement : {p0}'**
  String chatErreurTelechargement(Object p0);

  /// No description provided for @chatVideoEnregistreeDansLaGalerie.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo enregistrée dans la galerie'**
  String get chatVideoEnregistreeDansLaGalerie;

  /// No description provided for @chatEnregistrer.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get chatEnregistrer;

  /// No description provided for @chatPartagerVers.
  ///
  /// In fr, this message translates to:
  /// **'Partager vers…'**
  String get chatPartagerVers;

  /// No description provided for @chatVousNAvezEncoreAucun.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez encore aucun groupe.\nCréez-en un pour pouvoir partager.'**
  String get chatVousNAvezEncoreAucun;

  /// No description provided for @chatEchecDuPartage.
  ///
  /// In fr, this message translates to:
  /// **'Échec du partage : {p0}'**
  String chatEchecDuPartage(Object p0);

  /// No description provided for @chatCreerUnSondage.
  ///
  /// In fr, this message translates to:
  /// **'Créer un sondage'**
  String get chatCreerUnSondage;

  /// No description provided for @chatOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options'**
  String get chatOptions;

  /// No description provided for @chatAjouterUneOption.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une option'**
  String get chatAjouterUneOption;

  /// No description provided for @chatReponsesMultiples.
  ///
  /// In fr, this message translates to:
  /// **'Réponses multiples'**
  String get chatReponsesMultiples;

  /// No description provided for @chatLesParticipantsPeuventVoterPour.
  ///
  /// In fr, this message translates to:
  /// **'Les participants peuvent voter pour plusieurs options'**
  String get chatLesParticipantsPeuventVoterPour;

  /// No description provided for @chatCreer.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get chatCreer;

  /// No description provided for @chatQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Question'**
  String get chatQuestion;

  /// No description provided for @chatPosezVotreQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Posez votre question…'**
  String get chatPosezVotreQuestion;

  /// No description provided for @chatOption.
  ///
  /// In fr, this message translates to:
  /// **'Option {p0}'**
  String chatOption(Object p0);

  /// No description provided for @chatLesVotesExistantsSerontReinitialises.
  ///
  /// In fr, this message translates to:
  /// **'Les votes existants seront réinitialisés.'**
  String get chatLesVotesExistantsSerontReinitialises;

  /// No description provided for @chatAudio.
  ///
  /// In fr, this message translates to:
  /// **'🎵 Audio'**
  String get chatAudio;

  /// No description provided for @chatImage2.
  ///
  /// In fr, this message translates to:
  /// **'🖼️ Image'**
  String get chatImage2;

  /// No description provided for @chatMedia.
  ///
  /// In fr, this message translates to:
  /// **'🖼️ Média'**
  String get chatMedia;

  /// No description provided for @chatChoixMultiples.
  ///
  /// In fr, this message translates to:
  /// **'Choix multiples'**
  String get chatChoixMultiples;

  /// No description provided for @chatReactions.
  ///
  /// In fr, this message translates to:
  /// **'Réactions'**
  String get chatReactions;

  /// No description provided for @dashboardTotalDuGroupe.
  ///
  /// In fr, this message translates to:
  /// **'total du groupe'**
  String get dashboardTotalDuGroupe;

  /// No description provided for @dashboardMediasPartages.
  ///
  /// In fr, this message translates to:
  /// **'Médias partagés'**
  String get dashboardMediasPartages;

  /// No description provided for @dashboardVoirTout.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get dashboardVoirTout;

  /// No description provided for @dashboardActionsRapides.
  ///
  /// In fr, this message translates to:
  /// **'Actions rapides'**
  String get dashboardActionsRapides;

  /// No description provided for @dashboardProchainsEvenements.
  ///
  /// In fr, this message translates to:
  /// **'Prochains événements'**
  String get dashboardProchainsEvenements;

  /// No description provided for @dashboardAucunEvenementAVenir.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement à venir'**
  String get dashboardAucunEvenementAVenir;

  /// No description provided for @dashboardResumeDesDepenses.
  ///
  /// In fr, this message translates to:
  /// **'Résumé des dépenses'**
  String get dashboardResumeDesDepenses;

  /// No description provided for @dashboardVotreSolde.
  ///
  /// In fr, this message translates to:
  /// **'Votre solde'**
  String get dashboardVotreSolde;

  /// No description provided for @dashboardAjouterUnEvenement.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un événement'**
  String get dashboardAjouterUnEvenement;

  /// No description provided for @dashboardNouvelleNote.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle note'**
  String get dashboardNouvelleNote;

  /// No description provided for @dashboardChoisirUnEmoji.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un emoji'**
  String get dashboardChoisirUnEmoji;

  /// No description provided for @dashboardChoisirUnePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo'**
  String get dashboardChoisirUnePhoto;

  /// No description provided for @dashboardPrendreUnePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get dashboardPrendreUnePhoto;

  /// No description provided for @dashboardSupprimerLaPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la photo'**
  String get dashboardSupprimerLaPhoto;

  /// No description provided for @dashboardEmojiDuGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Emoji du groupe'**
  String get dashboardEmojiDuGroupe;

  /// No description provided for @dashboardAnnuler.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get dashboardAnnuler;

  /// No description provided for @dashboardEnregistrer.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get dashboardEnregistrer;

  /// No description provided for @dashboardErreur.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {p0}'**
  String dashboardErreur(Object p0);

  /// No description provided for @dashboardModifierLeGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le groupe'**
  String get dashboardModifierLeGroupe;

  /// No description provided for @dashboardNom.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get dashboardNom;

  /// No description provided for @dashboardDescriptionOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'Description (optionnel)'**
  String get dashboardDescriptionOptionnel;

  /// No description provided for @dashboardMonPseudoDansCeGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Mon pseudo dans ce groupe'**
  String get dashboardMonPseudoDansCeGroupe;

  /// No description provided for @dashboardRegenererLeLien.
  ///
  /// In fr, this message translates to:
  /// **'Régénérer le lien ?'**
  String get dashboardRegenererLeLien;

  /// No description provided for @dashboardRegenerer.
  ///
  /// In fr, this message translates to:
  /// **'Régénérer'**
  String get dashboardRegenerer;

  /// No description provided for @dashboardQuitterLeGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le groupe'**
  String get dashboardQuitterLeGroupe;

  /// No description provided for @dashboardEsTuSurDeVouloir.
  ///
  /// In fr, this message translates to:
  /// **'Es-tu sûr de vouloir quitter ce groupe ? Tu ne pourras plus accéder à son contenu.'**
  String get dashboardEsTuSurDeVouloir;

  /// No description provided for @dashboardQuitter.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get dashboardQuitter;

  /// No description provided for @dashboardImpossibleDeQuitterLeGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de quitter le groupe.'**
  String get dashboardImpossibleDeQuitterLeGroupe;

  /// No description provided for @dashboardSupprimerLeGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le groupe'**
  String get dashboardSupprimerLeGroupe;

  /// No description provided for @dashboardCetteActionEstIrreversibleTout.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Tout le contenu du groupe sera perdu.'**
  String get dashboardCetteActionEstIrreversibleTout;

  /// No description provided for @dashboardSupprimer.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get dashboardSupprimer;

  /// No description provided for @dashboardTransfererLaPropriete.
  ///
  /// In fr, this message translates to:
  /// **'Transférer la propriété'**
  String get dashboardTransfererLaPropriete;

  /// No description provided for @dashboardNommerProprietaireDuGroupeTu.
  ///
  /// In fr, this message translates to:
  /// **'Nommer {p0} propriétaire du groupe ? Tu deviendras simple membre.'**
  String dashboardNommerProprietaireDuGroupeTu(Object p0);

  /// No description provided for @dashboardTransferer.
  ///
  /// In fr, this message translates to:
  /// **'Transférer'**
  String get dashboardTransferer;

  /// No description provided for @dashboardRetirerLeMembre.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le membre'**
  String get dashboardRetirerLeMembre;

  /// No description provided for @dashboardRetirerDuGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {p0} du groupe ?'**
  String dashboardRetirerDuGroupe(Object p0);

  /// No description provided for @dashboardRetirer.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get dashboardRetirer;

  /// No description provided for @dashboardPseudo.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo'**
  String get dashboardPseudo;

  /// No description provided for @dashboardParametresAccueil.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres Accueil'**
  String get dashboardParametresAccueil;

  /// No description provided for @dashboardPartageLeLienOuLe.
  ///
  /// In fr, this message translates to:
  /// **'Partage le lien ou le code pour inviter quelqu\'un dans ce groupe.'**
  String get dashboardPartageLeLienOuLe;

  /// No description provided for @dashboardGenererUnCode.
  ///
  /// In fr, this message translates to:
  /// **'Générer un code'**
  String get dashboardGenererUnCode;

  /// No description provided for @dashboardCodeCopie.
  ///
  /// In fr, this message translates to:
  /// **'Code copié !'**
  String get dashboardCodeCopie;

  /// No description provided for @dashboardPartagerLeLienDInvitation.
  ///
  /// In fr, this message translates to:
  /// **'Partager le lien d\'invitation'**
  String get dashboardPartagerLeLienDInvitation;

  /// No description provided for @dashboardRegenererLeLien2.
  ///
  /// In fr, this message translates to:
  /// **'Régénérer le lien'**
  String get dashboardRegenererLeLien2;

  /// No description provided for @dashboardNommerProprietaire.
  ///
  /// In fr, this message translates to:
  /// **'Nommer propriétaire'**
  String get dashboardNommerProprietaire;

  /// No description provided for @dashboardRetirerDuGroupe2.
  ///
  /// In fr, this message translates to:
  /// **'Retirer du groupe'**
  String get dashboardRetirerDuGroupe2;

  /// No description provided for @dashboardImpossibleDeQuitter.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de quitter'**
  String get dashboardImpossibleDeQuitter;

  /// No description provided for @dashboardTuEsProprietaireDuGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Tu es propriétaire du groupe. Transfère la propriété à un autre membre avant de quitter.'**
  String get dashboardTuEsProprietaireDuGroupe;

  /// No description provided for @dashboardOk.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get dashboardOk;

  /// No description provided for @dashboardQuitterCeGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Quitter ce groupe'**
  String get dashboardQuitterCeGroupe;

  /// No description provided for @dashboardEspace.
  ///
  /// In fr, this message translates to:
  /// **'Espace'**
  String get dashboardEspace;

  /// No description provided for @dashboardCouleurDuTheme.
  ///
  /// In fr, this message translates to:
  /// **'Couleur du thème'**
  String get dashboardCouleurDuTheme;

  /// No description provided for @dashboardMembres.
  ///
  /// In fr, this message translates to:
  /// **'Membres'**
  String get dashboardMembres;

  /// No description provided for @dashboardChangerMonPseudo.
  ///
  /// In fr, this message translates to:
  /// **'Changer mon pseudo'**
  String get dashboardChangerMonPseudo;

  /// No description provided for @dashboardAjouter.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get dashboardAjouter;

  /// No description provided for @dashboardNoteEpinglee.
  ///
  /// In fr, this message translates to:
  /// **'Note épinglée'**
  String get dashboardNoteEpinglee;

  /// No description provided for @dashboardModifie.
  ///
  /// In fr, this message translates to:
  /// **'Modifié {p0}'**
  String dashboardModifie(Object p0);

  /// No description provided for @expensesErreur.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {p0}'**
  String expensesErreur(Object p0);

  /// No description provided for @expensesSupprimerLaDepense.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la dépense'**
  String get expensesSupprimerLaDepense;

  /// No description provided for @expensesCetteActionEstIrreversible.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible.'**
  String get expensesCetteActionEstIrreversible;

  /// No description provided for @expensesAnnuler.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get expensesAnnuler;

  /// No description provided for @expensesSupprimer.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get expensesSupprimer;

  /// No description provided for @expensesPermissionRefusee.
  ///
  /// In fr, this message translates to:
  /// **'Permission refusée'**
  String get expensesPermissionRefusee;

  /// No description provided for @expensesRepetition.
  ///
  /// In fr, this message translates to:
  /// **'Répétition'**
  String get expensesRepetition;

  /// No description provided for @expensesAucune.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get expensesAucune;

  /// No description provided for @expensesFinDeLaRepetition.
  ///
  /// In fr, this message translates to:
  /// **'Fin de la répétition'**
  String get expensesFinDeLaRepetition;

  /// No description provided for @expensesToujours.
  ///
  /// In fr, this message translates to:
  /// **'Toujours'**
  String get expensesToujours;

  /// No description provided for @expensesNombreDeFois.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de fois :'**
  String get expensesNombreDeFois;

  /// No description provided for @expensesNombreDeFois2.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de fois'**
  String get expensesNombreDeFois2;

  /// No description provided for @expensesJusquAu.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'au :'**
  String get expensesJusquAu;

  /// No description provided for @expensesJusquAu2.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'au'**
  String get expensesJusquAu2;

  /// No description provided for @expensesConfirmer.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get expensesConfirmer;

  /// No description provided for @expensesDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get expensesDate;

  /// No description provided for @expensesPayePar.
  ///
  /// In fr, this message translates to:
  /// **'Payé par'**
  String get expensesPayePar;

  /// No description provided for @expensesPartagerAvec.
  ///
  /// In fr, this message translates to:
  /// **'Partager avec'**
  String get expensesPartagerAvec;

  /// No description provided for @expensesRepartition.
  ///
  /// In fr, this message translates to:
  /// **'Répartition'**
  String get expensesRepartition;

  /// No description provided for @expensesEquitable.
  ///
  /// In fr, this message translates to:
  /// **'Équitable'**
  String get expensesEquitable;

  /// No description provided for @expensesParMontant.
  ///
  /// In fr, this message translates to:
  /// **'Par montant'**
  String get expensesParMontant;

  /// No description provided for @expensesParPourcentage.
  ///
  /// In fr, this message translates to:
  /// **'Par pourcentage'**
  String get expensesParPourcentage;

  /// No description provided for @expensesCategorie.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get expensesCategorie;

  /// No description provided for @expensesNouvelleCategorie.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle catégorie'**
  String get expensesNouvelleCategorie;

  /// No description provided for @expensesTitre.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get expensesTitre;

  /// No description provided for @expensesMontant.
  ///
  /// In fr, this message translates to:
  /// **'Montant (€)'**
  String get expensesMontant;

  /// No description provided for @expensesRechercherUneDepense.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une dépense...'**
  String get expensesRechercherUneDepense;

  /// No description provided for @expensesParametresDepenses.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres Dépenses'**
  String get expensesParametresDepenses;

  /// No description provided for @expensesApparence.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get expensesApparence;

  /// No description provided for @expensesDevise.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get expensesDevise;

  /// No description provided for @expensesCategories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get expensesCategories;

  /// No description provided for @expensesAjouterUneCategorie.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une catégorie'**
  String get expensesAjouterUneCategorie;

  /// No description provided for @expensesRemboursement.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement'**
  String get expensesRemboursement;

  /// No description provided for @expensesJeRembourseA.
  ///
  /// In fr, this message translates to:
  /// **'Je rembourse à'**
  String get expensesJeRembourseA;

  /// No description provided for @expensesLibelleOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'Libellé (optionnel)'**
  String get expensesLibelleOptionnel;

  /// No description provided for @expensesApercuDuGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu du groupe'**
  String get expensesApercuDuGroupe;

  /// No description provided for @expensesAucuneDepense.
  ///
  /// In fr, this message translates to:
  /// **'Aucune dépense'**
  String get expensesAucuneDepense;

  /// No description provided for @expensesAjouter.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get expensesAjouter;

  /// No description provided for @expensesDepensesRecentes.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses récentes'**
  String get expensesDepensesRecentes;

  /// No description provided for @expensesTotalDepenses.
  ///
  /// In fr, this message translates to:
  /// **'Total dépenses'**
  String get expensesTotalDepenses;

  /// No description provided for @expensesVotrePart.
  ///
  /// In fr, this message translates to:
  /// **'Votre part'**
  String get expensesVotrePart;

  /// No description provided for @expensesVotreSolde.
  ///
  /// In fr, this message translates to:
  /// **'Votre solde'**
  String get expensesVotreSolde;

  /// No description provided for @expensesSoldes.
  ///
  /// In fr, this message translates to:
  /// **'Soldes'**
  String get expensesSoldes;

  /// No description provided for @expensesARegler.
  ///
  /// In fr, this message translates to:
  /// **'À régler'**
  String get expensesARegler;

  /// No description provided for @expensesRembourser.
  ///
  /// In fr, this message translates to:
  /// **'Rembourser'**
  String get expensesRembourser;

  /// No description provided for @expensesLesComptesSontEquilibres.
  ///
  /// In fr, this message translates to:
  /// **'Les comptes sont équilibrés'**
  String get expensesLesComptesSontEquilibres;

  /// No description provided for @groupsMesEspaces.
  ///
  /// In fr, this message translates to:
  /// **'Mes espaces'**
  String get groupsMesEspaces;

  /// No description provided for @groupsMonProfil.
  ///
  /// In fr, this message translates to:
  /// **'Mon profil'**
  String get groupsMonProfil;

  /// No description provided for @groupsNouvelEspace.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel espace'**
  String get groupsNouvelEspace;

  /// No description provided for @groupsCreer.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get groupsCreer;

  /// No description provided for @groupsNomDeLEspace.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'espace'**
  String get groupsNomDeLEspace;

  /// No description provided for @groupsDescriptionOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'Description (optionnel)'**
  String get groupsDescriptionOptionnel;

  /// No description provided for @groupsRejoindre.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get groupsRejoindre;

  /// No description provided for @groupsAucunEspace.
  ///
  /// In fr, this message translates to:
  /// **'Aucun espace'**
  String get groupsAucunEspace;

  /// No description provided for @groupsCreeOuRejoinsUnEspace.
  ///
  /// In fr, this message translates to:
  /// **'Crée ou rejoins un espace partagé pour commencer.'**
  String get groupsCreeOuRejoinsUnEspace;

  /// No description provided for @groupsCreerUnEspace.
  ///
  /// In fr, this message translates to:
  /// **'Créer un espace'**
  String get groupsCreerUnEspace;

  /// No description provided for @groupsRejoindreAvecUnCode.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre avec un code'**
  String get groupsRejoindreAvecUnCode;

  /// No description provided for @groupsReessayer.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get groupsReessayer;

  /// No description provided for @groupsCodeCopie.
  ///
  /// In fr, this message translates to:
  /// **'Code {p0} copié !'**
  String groupsCodeCopie(Object p0);

  /// No description provided for @groupsOuvrirCetEspace.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir cet espace'**
  String get groupsOuvrirCetEspace;

  /// No description provided for @groupsRejoindreUnEspace.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre un espace'**
  String get groupsRejoindreUnEspace;

  /// No description provided for @groupsEntreLeCodePartagePar.
  ///
  /// In fr, this message translates to:
  /// **'Entre le code partagé par un membre du groupe.'**
  String get groupsEntreLeCodePartagePar;

  /// No description provided for @groupsCodeDInvitation.
  ///
  /// In fr, this message translates to:
  /// **'Code d\'invitation'**
  String get groupsCodeDInvitation;

  /// No description provided for @groupsLienInvalide.
  ///
  /// In fr, this message translates to:
  /// **'Lien invalide'**
  String get groupsLienInvalide;

  /// No description provided for @groupsFermer.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get groupsFermer;

  /// No description provided for @notesErreur.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {p0}'**
  String notesErreur(Object p0);

  /// No description provided for @notesSupprimerLaNote.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la note'**
  String get notesSupprimerLaNote;

  /// No description provided for @notesCetteActionEstIrreversible.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible.'**
  String get notesCetteActionEstIrreversible;

  /// No description provided for @notesAnnuler.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get notesAnnuler;

  /// No description provided for @notesSupprimer.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get notesSupprimer;

  /// No description provided for @notesPermissionRefusee.
  ///
  /// In fr, this message translates to:
  /// **'Permission refusée'**
  String get notesPermissionRefusee;

  /// No description provided for @notesCouleur.
  ///
  /// In fr, this message translates to:
  /// **'Couleur'**
  String get notesCouleur;

  /// No description provided for @notesAjouterUnElement.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un élément'**
  String get notesAjouterUnElement;

  /// No description provided for @notesTitre.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get notesTitre;

  /// No description provided for @notesEpingler.
  ///
  /// In fr, this message translates to:
  /// **'Épingler'**
  String get notesEpingler;

  /// No description provided for @notesChecklist.
  ///
  /// In fr, this message translates to:
  /// **'Checklist'**
  String get notesChecklist;

  /// No description provided for @notesContenuOptionnel.
  ///
  /// In fr, this message translates to:
  /// **'Contenu (optionnel)'**
  String get notesContenuOptionnel;

  /// No description provided for @notesElement.
  ///
  /// In fr, this message translates to:
  /// **'Élément {p0}…'**
  String notesElement(Object p0);

  /// No description provided for @notesImpossibleDEpinglerPermissionRefusee.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'épingler : permission refusée.'**
  String get notesImpossibleDEpinglerPermissionRefusee;

  /// No description provided for @notesAucuneNote.
  ///
  /// In fr, this message translates to:
  /// **'Aucune note'**
  String get notesAucuneNote;

  /// No description provided for @notesCreerUneNote.
  ///
  /// In fr, this message translates to:
  /// **'Créer une note'**
  String get notesCreerUneNote;

  /// No description provided for @notesEpinglees.
  ///
  /// In fr, this message translates to:
  /// **'Épinglées'**
  String get notesEpinglees;

  /// No description provided for @notesRecentes.
  ///
  /// In fr, this message translates to:
  /// **'Récentes'**
  String get notesRecentes;

  /// No description provided for @notesRechercher.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher...'**
  String get notesRechercher;

  /// No description provided for @notesParametresNotes.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres Notes'**
  String get notesParametresNotes;

  /// No description provided for @notesApparence.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get notesApparence;

  /// No description provided for @notesCouleurDuTheme.
  ///
  /// In fr, this message translates to:
  /// **'Couleur du thème'**
  String get notesCouleurDuTheme;

  /// No description provided for @commonIcone.
  ///
  /// In fr, this message translates to:
  /// **'Icône'**
  String get commonIcone;

  /// No description provided for @commonCouleur.
  ///
  /// In fr, this message translates to:
  /// **'Couleur'**
  String get commonCouleur;

  /// No description provided for @commonAnnuler.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get commonAnnuler;

  /// No description provided for @commonNom.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get commonNom;

  /// No description provided for @commonExSanteEducation.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Santé, Éducation...'**
  String get commonExSanteEducation;

  /// No description provided for @commonAjouter.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get commonAjouter;

  /// No description provided for @commonSupprimerCetteCouleur.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette couleur ?'**
  String get commonSupprimerCetteCouleur;

  /// No description provided for @commonCetteCouleurSeraRetireeDe.
  ///
  /// In fr, this message translates to:
  /// **'Cette couleur sera retirée de la palette.'**
  String get commonCetteCouleurSeraRetireeDe;

  /// No description provided for @commonSupprimer.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get commonSupprimer;

  /// No description provided for @commonRrggbb.
  ///
  /// In fr, this message translates to:
  /// **'RRGGBB'**
  String get commonRrggbb;

  /// Nombre de membres d'un espace (pluriel identique à l'historique : « s » à partir de 2)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 membre} =1{1 membre} other{{count} membres}}'**
  String commonMemberCount(int count);

  /// No description provided for @groupsInvalidInviteLinkBody.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien d\'invitation est invalide ou a expiré. Demande un nouveau lien à un membre du groupe.'**
  String get groupsInvalidInviteLinkBody;

  /// No description provided for @dashboardRegenerateCodeBody.
  ///
  /// In fr, this message translates to:
  /// **'Un nouveau code sera créé. Les liens et codes déjà partagés cesseront de fonctionner.'**
  String get dashboardRegenerateCodeBody;

  /// No description provided for @notesMoreItems.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{+ 0 autre} =1{+ 1 autre} other{+ {count} autres}}'**
  String notesMoreItems(int count);

  /// No description provided for @expensesPaidByYou.
  ///
  /// In fr, this message translates to:
  /// **'Payé par vous'**
  String get expensesPaidByYou;

  /// No description provided for @expensesPaidBy.
  ///
  /// In fr, this message translates to:
  /// **'Payé par {name}'**
  String expensesPaidBy(String name);

  /// No description provided for @chatPollVoteCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 votes} =1{1 vote} other{{count} votes}}'**
  String chatPollVoteCount(int count);

  /// No description provided for @chatPollYours.
  ///
  /// In fr, this message translates to:
  /// **'Votre sondage'**
  String get chatPollYours;

  /// No description provided for @chatPollEditedSuffix.
  ///
  /// In fr, this message translates to:
  /// **' · modifié'**
  String get chatPollEditedSuffix;
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
