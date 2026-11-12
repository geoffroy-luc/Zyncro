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

  @override
  String get authEmailDeReinitialisationEnvoye =>
      'Email de réinitialisation envoyé !';

  @override
  String get authZyncro => 'Zyncro';

  @override
  String get authRetrouveTonEspacePartage => 'Retrouve ton espace partagé';

  @override
  String get authMotDePasseOublie => 'Mot de passe oublié ?';

  @override
  String get authSeConnecter => 'Se connecter';

  @override
  String get authOu => 'ou';

  @override
  String get authContinuerAvecGoogle => 'Continuer avec Google';

  @override
  String get authContinuerAvecApple => 'Continuer avec Apple';

  @override
  String get authContinuerSansCompte => 'Continuer sans compte';

  @override
  String get authPasEncoreDeCompteS => 'Pas encore de compte ? S\'inscrire';

  @override
  String get authEmail => 'Email';

  @override
  String get authMotDePasse => 'Mot de passe';

  @override
  String get authModifierLePseudo => 'Modifier le pseudo';

  @override
  String get authAnnuler => 'Annuler';

  @override
  String get authEnregistrer => 'Enregistrer';

  @override
  String get authPrendreUnePhoto => 'Prendre une photo';

  @override
  String get authChoisirDepuisLaGalerie => 'Choisir depuis la galerie';

  @override
  String get authReinitialiserAvecLaPhotoGoogle =>
      'Réinitialiser avec la photo Google/Apple';

  @override
  String authErreur(Object p0) {
    return 'Erreur : $p0';
  }

  @override
  String get authSeDeconnecter => 'Se déconnecter';

  @override
  String get authConfirmesTuLaDeconnexion => 'Confirmes-tu la déconnexion ?';

  @override
  String get authDeconnecter => 'Déconnecter';

  @override
  String get authSupprimerLeCompte => 'Supprimer le compte';

  @override
  String get authCetteActionEstIrreversibleTon =>
      'Cette action est irréversible. Ton compte et toutes tes données seront définitivement supprimés.';

  @override
  String get authSupprimer => 'Supprimer';

  @override
  String get authMonProfil => 'Mon profil';

  @override
  String get authPseudo => 'Pseudo';

  @override
  String get authAfficherMaPhotoDeProfil => 'Afficher ma photo de profil';

  @override
  String get authNotifications => 'Notifications';

  @override
  String get authInformations => 'Informations';

  @override
  String get authPreferences => 'Préférences';

  @override
  String get authCompte => 'Compte';

  @override
  String get authCreerUnCompte => 'Créer un compte';

  @override
  String get authRejoinsOuCreeTonEspace => 'Rejoins ou crée ton espace partagé';

  @override
  String get authSInscrire => 'S\'inscrire';

  @override
  String get authDejaUnCompteSeConnecter => 'Déjà un compte ? Se connecter';

  @override
  String get authPrenomOuPseudo => 'Prénom ou pseudo';

  @override
  String get authConfirmerLeMotDePasse => 'Confirmer le mot de passe';

  @override
  String get authG => 'G';

  @override
  String get authEntreUnPseudoPourEtre =>
      'Entre un pseudo pour être identifié dans ton groupe.';

  @override
  String get authContinuer => 'Continuer';

  @override
  String get calendarAucunEvenement => 'Aucun événement';

  @override
  String get calendarAjouterUnEvenement => 'Ajouter un événement';

  @override
  String get calendarRechercher => 'Rechercher...';

  @override
  String get calendarMois => 'Mois';

  @override
  String get calendarAgenda => 'Agenda';

  @override
  String get calendarFiltres => 'Filtres';

  @override
  String get calendarReinitialiser => 'Réinitialiser';

  @override
  String get calendarParticipants => 'Participants';

  @override
  String get calendarRecurrentsUniquement => 'Récurrents uniquement';

  @override
  String get calendarAppliquer => 'Appliquer';

  @override
  String get calendarParametresCalendrier => 'Paramètres Calendrier';

  @override
  String get calendarBande => 'Bande';

  @override
  String get calendarPoint => 'Point';

  @override
  String get calendarApparence => 'Apparence';

  @override
  String get calendarAffichage => 'Affichage';

  @override
  String get calendarSupprimerLEvenement => 'Supprimer l\'événement';

  @override
  String get calendarCetteActionEstIrreversible =>
      'Cette action est irréversible.';

  @override
  String get calendarAnnuler => 'Annuler';

  @override
  String get calendarSupprimer => 'Supprimer';

  @override
  String get calendarPermissionRefusee => 'Permission refusée';

  @override
  String get calendarLaDateDeFinDoit =>
      'La date de fin doit être après la date de début';

  @override
  String calendarErreur(Object p0) {
    return 'Erreur: $p0';
  }

  @override
  String get calendarRepetition => 'Répétition';

  @override
  String get calendarAucune => 'Aucune';

  @override
  String get calendarFinDeLaRepetition => 'Fin de la répétition';

  @override
  String get calendarToujours => 'Toujours';

  @override
  String get calendarNombreDeFois => 'Nombre de fois :';

  @override
  String get calendarNombreDeFois2 => 'Nombre de fois';

  @override
  String get calendarJusquAu => 'Jusqu\'au :';

  @override
  String get calendarJusquAu2 => 'Jusqu\'au';

  @override
  String get calendarConfirmer => 'Confirmer';

  @override
  String get calendarRappel => 'Rappel';

  @override
  String get calendarPersonnalise => 'Personnalisé…';

  @override
  String get calendarRappelPersonnalise => 'Rappel personnalisé';

  @override
  String get calendarMin => 'min';

  @override
  String get calendarH => 'h';

  @override
  String get calendarJ => 'j';

  @override
  String get calendarOk => 'OK';

  @override
  String get calendarCouleur => 'Couleur';

  @override
  String get calendarAjouterUneHeureDeFin => 'Ajouter une heure de fin';

  @override
  String get calendarTitre => 'Titre';

  @override
  String get calendarLieuOptionnel => 'Lieu (optionnel)';

  @override
  String get calendarDescriptionOptionnel => 'Description (optionnel)';

  @override
  String get calendarDebut => 'Début';

  @override
  String get calendarFin => 'Fin';

  @override
  String chatErreur(Object p0) {
    return 'Erreur: $p0';
  }

  @override
  String get chatAucunMessageSoyezLePremier =>
      'Aucun message. Soyez le premier !';

  @override
  String get chatReplyPhoto => 'Photo';

  @override
  String get chatReplyVideo => 'Vidéo';

  @override
  String get chatReplyAlbum => 'Album';

  @override
  String get chatReplyAudio => 'Audio';

  @override
  String get chatReplyPoll => 'Sondage';

  @override
  String get chatAucunResultat => 'Aucun message ne correspond à la recherche.';

  @override
  String chatMediasEnregistres(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count médias enregistrés dans la galerie',
      one: '1 média enregistré dans la galerie',
      zero: 'Aucun média enregistré',
    );
    return '$_temp0';
  }

  @override
  String get expensesErreurChargement => 'Impossible de charger les dépenses.';

  @override
  String get expensesModifierRecurrente => 'Modifier une dépense récurrente';

  @override
  String get expensesSupprimerRecurrente => 'Supprimer une dépense récurrente';

  @override
  String get calendarModifierRecurrent => 'Modifier un événement récurrent';

  @override
  String get calendarSupprimerRecurrent => 'Supprimer un événement récurrent';

  @override
  String get seriesPorteeExplication =>
      'Appliquer à cette occurrence et aux suivantes, ou à toute la série (occurrences passées comprises) ?';

  @override
  String get seriesAnnuler => 'Annuler';

  @override
  String get seriesToute => 'Toute la série';

  @override
  String get seriesCelleCiEtSuivantes => 'Celle-ci et les suivantes';

  @override
  String get seriesSuppressionSerieEntiere =>
      'C\'est la première occurrence : toute la série sera supprimée. Cette action est irréversible.';

  @override
  String get chatEchecEnvoiMessage => 'Échec de l\'envoi du message.';

  @override
  String get chatModifierLeMessage => 'Modifier le message';

  @override
  String get chatEnregistrement => 'Enregistrement…';

  @override
  String get chatRechercherDansLeChat => 'Rechercher dans le chat...';

  @override
  String get chatEcrireUnMessage => 'Écrire un message...';

  @override
  String get chatMessageIntrouvable => 'Message introuvable';

  @override
  String get chatImpossibleDeModifierLeMessage =>
      'Impossible de modifier le message.';

  @override
  String chatErreurEnvoiMedia(Object p0) {
    return 'Erreur envoi média : $p0';
  }

  @override
  String get chatRepondre => 'Répondre';

  @override
  String get chatCopier => 'Copier';

  @override
  String get chatModifier => 'Modifier';

  @override
  String get chatModifierLeSondage => 'Modifier le sondage';

  @override
  String get chatTelecharger => 'Télécharger';

  @override
  String get chatSupprimer => 'Supprimer';

  @override
  String get chatMessageCopie => 'Message copié';

  @override
  String get chatImpossibleDeModifierLeSondage =>
      'Impossible de modifier le sondage.';

  @override
  String get chatSupprimerLeMessage => 'Supprimer le message';

  @override
  String get chatCeMessageSeraSupprimeDefinitivement =>
      'Ce message sera supprimé définitivement.';

  @override
  String get chatAnnuler => 'Annuler';

  @override
  String get chatImpossibleDeSupprimerLeMessage =>
      'Impossible de supprimer le message.';

  @override
  String get chatPermissionMicrophoneRefusee =>
      'Permission microphone refusée.';

  @override
  String chatAudioError(Object p0) {
    return 'Audio error: $p0';
  }

  @override
  String get chatPrendreUnePhoto => 'Prendre une photo';

  @override
  String get chatChoisirDepuisLaGalerie => 'Choisir depuis la galerie';

  @override
  String chatErreur2(Object p0) {
    return 'Erreur : $p0';
  }

  @override
  String get chatParametresChat => 'Paramètres Chat';

  @override
  String get chatAucun => 'Aucun';

  @override
  String get chatCouleur => 'Couleur';

  @override
  String get chatImage => 'Image';

  @override
  String get chatApparence => 'Apparence';

  @override
  String get chatCouleurDuTheme => 'Couleur du thème';

  @override
  String get chatBackgroundDuChat => 'Background du chat';

  @override
  String get chatCouleurDuFond => 'Couleur du fond';

  @override
  String get chatChangerLImage => 'Changer l\'image';

  @override
  String get chatPhotosVideosPartagees => 'Photos & vidéos partagées';

  @override
  String get chatVoirTousLesMediasDu => 'Voir tous les médias du groupe';

  @override
  String get chatMediasPartages => 'Médias partagés';

  @override
  String get chatAucunMediaPartage => 'Aucun média partagé';

  @override
  String chatEnvoyer(Object p0) {
    return 'Envoyer ($p0)';
  }

  @override
  String get chatAccesALaGalerieRefuse => 'Accès à la galerie refusé';

  @override
  String get chatOuvrirLesReglages => 'Ouvrir les réglages';

  @override
  String get chatAccesLimiteACertainesPhotos =>
      'Accès limité à certaines photos';

  @override
  String get chatToutAutoriser => 'Tout autoriser';

  @override
  String get chatAucunMedia => 'Aucun média';

  @override
  String get chatImageEnregistreeDansLaGalerie =>
      'Image enregistrée dans la galerie';

  @override
  String chatErreurTelechargement(Object p0) {
    return 'Erreur téléchargement : $p0';
  }

  @override
  String get chatVideoEnregistreeDansLaGalerie =>
      'Vidéo enregistrée dans la galerie';

  @override
  String get chatEnregistrer => 'Enregistrer';

  @override
  String get chatPartagerVers => 'Partager vers…';

  @override
  String get chatVousNAvezEncoreAucun =>
      'Vous n\'avez encore aucun groupe.\nCréez-en un pour pouvoir partager.';

  @override
  String chatEchecDuPartage(Object p0) {
    return 'Échec du partage : $p0';
  }

  @override
  String get chatCreerUnSondage => 'Créer un sondage';

  @override
  String get chatOptions => 'Options';

  @override
  String get chatAjouterUneOption => 'Ajouter une option';

  @override
  String get chatReponsesMultiples => 'Réponses multiples';

  @override
  String get chatLesParticipantsPeuventVoterPour =>
      'Les participants peuvent voter pour plusieurs options';

  @override
  String get chatCreer => 'Créer';

  @override
  String get chatQuestion => 'Question';

  @override
  String get chatPosezVotreQuestion => 'Posez votre question…';

  @override
  String chatOption(Object p0) {
    return 'Option $p0';
  }

  @override
  String get chatLesVotesExistantsSerontReinitialises =>
      'Les votes existants seront réinitialisés.';

  @override
  String get chatAudio => '🎵 Audio';

  @override
  String get chatImage2 => '🖼️ Image';

  @override
  String get chatMedia => '🖼️ Média';

  @override
  String get chatChoixMultiples => 'Choix multiples';

  @override
  String get chatReactions => 'Réactions';

  @override
  String get dashboardTotalDuGroupe => 'total du groupe';

  @override
  String get dashboardMediasPartages => 'Médias partagés';

  @override
  String get dashboardVoirTout => 'Voir tout';

  @override
  String get dashboardActionsRapides => 'Actions rapides';

  @override
  String get dashboardProchainsEvenements => 'Prochains événements';

  @override
  String get dashboardAucunEvenementAVenir => 'Aucun événement à venir';

  @override
  String get dashboardResumeDesDepenses => 'Résumé des dépenses';

  @override
  String get dashboardVotreSolde => 'Votre solde';

  @override
  String get dashboardAjouterUnEvenement => 'Ajouter un événement';

  @override
  String get dashboardNouvelleNote => 'Nouvelle note';

  @override
  String get dashboardChoisirUnEmoji => 'Choisir un emoji';

  @override
  String get dashboardChoisirUnePhoto => 'Choisir une photo';

  @override
  String get dashboardPrendreUnePhoto => 'Prendre une photo';

  @override
  String get dashboardSupprimerLaPhoto => 'Supprimer la photo';

  @override
  String get dashboardEmojiDuGroupe => 'Emoji du groupe';

  @override
  String get dashboardAnnuler => 'Annuler';

  @override
  String get dashboardEnregistrer => 'Enregistrer';

  @override
  String dashboardErreur(Object p0) {
    return 'Erreur : $p0';
  }

  @override
  String get dashboardModifierLeGroupe => 'Modifier le groupe';

  @override
  String get dashboardNom => 'Nom';

  @override
  String get dashboardDescriptionOptionnel => 'Description (optionnel)';

  @override
  String get dashboardMonPseudoDansCeGroupe => 'Mon pseudo dans ce groupe';

  @override
  String get dashboardRegenererLeLien => 'Régénérer le lien ?';

  @override
  String get dashboardRegenerer => 'Régénérer';

  @override
  String get dashboardQuitterLeGroupe => 'Quitter le groupe';

  @override
  String get dashboardEsTuSurDeVouloir =>
      'Es-tu sûr de vouloir quitter ce groupe ? Tu ne pourras plus accéder à son contenu.';

  @override
  String get dashboardQuitter => 'Quitter';

  @override
  String get dashboardImpossibleDeQuitterLeGroupe =>
      'Impossible de quitter le groupe.';

  @override
  String get dashboardSupprimerLeGroupe => 'Supprimer le groupe';

  @override
  String get dashboardCetteActionEstIrreversibleTout =>
      'Cette action est irréversible. Tout le contenu du groupe sera perdu.';

  @override
  String get dashboardSupprimer => 'Supprimer';

  @override
  String get dashboardTransfererLaPropriete => 'Transférer la propriété';

  @override
  String dashboardNommerProprietaireDuGroupeTu(Object p0) {
    return 'Nommer $p0 propriétaire du groupe ? Tu deviendras simple membre.';
  }

  @override
  String get dashboardTransferer => 'Transférer';

  @override
  String get dashboardRetirerLeMembre => 'Retirer le membre';

  @override
  String dashboardRetirerDuGroupe(Object p0) {
    return 'Retirer $p0 du groupe ?';
  }

  @override
  String get dashboardRetirer => 'Retirer';

  @override
  String get dashboardPseudo => 'Pseudo';

  @override
  String get dashboardParametresAccueil => 'Paramètres Accueil';

  @override
  String get dashboardPartageLeLienOuLe =>
      'Partage le lien ou le code pour inviter quelqu\'un dans ce groupe.';

  @override
  String get dashboardGenererUnCode => 'Générer un code';

  @override
  String get dashboardCodeCopie => 'Code copié !';

  @override
  String get dashboardPartagerLeLienDInvitation =>
      'Partager le lien d\'invitation';

  @override
  String get dashboardRegenererLeLien2 => 'Régénérer le lien';

  @override
  String get dashboardNommerProprietaire => 'Nommer propriétaire';

  @override
  String get dashboardRetirerDuGroupe2 => 'Retirer du groupe';

  @override
  String get dashboardImpossibleDeQuitter => 'Impossible de quitter';

  @override
  String get dashboardTuEsProprietaireDuGroupe =>
      'Tu es propriétaire du groupe. Transfère la propriété à un autre membre avant de quitter.';

  @override
  String get dashboardOk => 'OK';

  @override
  String get dashboardQuitterCeGroupe => 'Quitter ce groupe';

  @override
  String get dashboardEspace => 'Espace';

  @override
  String get dashboardCouleurDuTheme => 'Couleur du thème';

  @override
  String get dashboardMembres => 'Membres';

  @override
  String get dashboardChangerMonPseudo => 'Changer mon pseudo';

  @override
  String get dashboardAjouter => 'Ajouter';

  @override
  String get dashboardNoteEpinglee => 'Note épinglée';

  @override
  String dashboardModifie(Object p0) {
    return 'Modifié $p0';
  }

  @override
  String expensesErreur(Object p0) {
    return 'Erreur: $p0';
  }

  @override
  String get expensesSupprimerLaDepense => 'Supprimer la dépense';

  @override
  String get expensesCetteActionEstIrreversible =>
      'Cette action est irréversible.';

  @override
  String get expensesAnnuler => 'Annuler';

  @override
  String get expensesSupprimer => 'Supprimer';

  @override
  String get expensesPermissionRefusee => 'Permission refusée';

  @override
  String get expensesRepetition => 'Répétition';

  @override
  String get expensesAucune => 'Aucune';

  @override
  String get expensesFinDeLaRepetition => 'Fin de la répétition';

  @override
  String get expensesToujours => 'Toujours';

  @override
  String get expensesNombreDeFois => 'Nombre de fois :';

  @override
  String get expensesNombreDeFois2 => 'Nombre de fois';

  @override
  String get expensesJusquAu => 'Jusqu\'au :';

  @override
  String get expensesJusquAu2 => 'Jusqu\'au';

  @override
  String get expensesConfirmer => 'Confirmer';

  @override
  String get expensesDate => 'Date';

  @override
  String get expensesPayePar => 'Payé par';

  @override
  String get expensesPartagerAvec => 'Partager avec';

  @override
  String get expensesRepartition => 'Répartition';

  @override
  String get expensesEquitable => 'Équitable';

  @override
  String get expensesParMontant => 'Par montant';

  @override
  String get expensesParPourcentage => 'Par pourcentage';

  @override
  String get expensesCategorie => 'Catégorie';

  @override
  String get expensesNouvelleCategorie => 'Nouvelle catégorie';

  @override
  String get expensesTitre => 'Titre';

  @override
  String get expensesMontant => 'Montant (€)';

  @override
  String get expensesRechercherUneDepense => 'Rechercher une dépense...';

  @override
  String get expensesParametresDepenses => 'Paramètres Dépenses';

  @override
  String get expensesApparence => 'Apparence';

  @override
  String get expensesDevise => 'Devise';

  @override
  String get expensesCategories => 'Catégories';

  @override
  String get expensesAjouterUneCategorie => 'Ajouter une catégorie';

  @override
  String get expensesRemboursement => 'Remboursement';

  @override
  String get expensesJeRembourseA => 'Je rembourse à';

  @override
  String get expensesLibelleOptionnel => 'Libellé (optionnel)';

  @override
  String get expensesApercuDuGroupe => 'Aperçu du groupe';

  @override
  String get expensesAucuneDepense => 'Aucune dépense';

  @override
  String get expensesAjouter => 'Ajouter';

  @override
  String get expensesDepensesRecentes => 'Dépenses récentes';

  @override
  String get expensesTotalDepenses => 'Total dépenses';

  @override
  String get expensesVotrePart => 'Votre part';

  @override
  String get expensesVotreSolde => 'Votre solde';

  @override
  String get expensesSoldes => 'Soldes';

  @override
  String get expensesARegler => 'À régler';

  @override
  String get expensesRembourser => 'Rembourser';

  @override
  String get expensesLesComptesSontEquilibres => 'Les comptes sont équilibrés';

  @override
  String get groupsMesEspaces => 'Mes espaces';

  @override
  String get groupsMonProfil => 'Mon profil';

  @override
  String get groupsNouvelEspace => 'Nouvel espace';

  @override
  String get groupsCreer => 'Créer';

  @override
  String get groupsNomDeLEspace => 'Nom de l\'espace';

  @override
  String get groupsDescriptionOptionnel => 'Description (optionnel)';

  @override
  String get groupsRejoindre => 'Rejoindre';

  @override
  String get groupsAucunEspace => 'Aucun espace';

  @override
  String get groupsCreeOuRejoinsUnEspace =>
      'Crée ou rejoins un espace partagé pour commencer.';

  @override
  String get groupsCreerUnEspace => 'Créer un espace';

  @override
  String get groupsRejoindreAvecUnCode => 'Rejoindre avec un code';

  @override
  String get groupsReessayer => 'Réessayer';

  @override
  String groupsCodeCopie(Object p0) {
    return 'Code $p0 copié !';
  }

  @override
  String get groupsOuvrirCetEspace => 'Ouvrir cet espace';

  @override
  String get groupsRejoindreUnEspace => 'Rejoindre un espace';

  @override
  String get groupsEntreLeCodePartagePar =>
      'Entre le code partagé par un membre du groupe.';

  @override
  String get groupsCodeDInvitation => 'Code d\'invitation';

  @override
  String get groupsLienInvalide => 'Lien invalide';

  @override
  String get groupsFermer => 'Fermer';

  @override
  String notesErreur(Object p0) {
    return 'Erreur: $p0';
  }

  @override
  String get notesSupprimerLaNote => 'Supprimer la note';

  @override
  String get notesCetteActionEstIrreversible =>
      'Cette action est irréversible.';

  @override
  String get notesAnnuler => 'Annuler';

  @override
  String get notesSupprimer => 'Supprimer';

  @override
  String get notesPermissionRefusee => 'Permission refusée';

  @override
  String get notesCouleur => 'Couleur';

  @override
  String get notesAjouterUnElement => 'Ajouter un élément';

  @override
  String get notesTitre => 'Titre';

  @override
  String get notesEpingler => 'Épingler';

  @override
  String get notesChecklist => 'Checklist';

  @override
  String get notesContenuOptionnel => 'Contenu (optionnel)';

  @override
  String notesElement(Object p0) {
    return 'Élément $p0…';
  }

  @override
  String get notesImpossibleDEpinglerPermissionRefusee =>
      'Impossible d\'épingler : permission refusée.';

  @override
  String get notesAucuneNote => 'Aucune note';

  @override
  String get notesCreerUneNote => 'Créer une note';

  @override
  String get notesEpinglees => 'Épinglées';

  @override
  String get notesRecentes => 'Récentes';

  @override
  String get notesRechercher => 'Rechercher...';

  @override
  String get notesParametresNotes => 'Paramètres Notes';

  @override
  String get notesApparence => 'Apparence';

  @override
  String get notesCouleurDuTheme => 'Couleur du thème';

  @override
  String get commonIcone => 'Icône';

  @override
  String get commonCouleur => 'Couleur';

  @override
  String get commonAnnuler => 'Annuler';

  @override
  String get commonNom => 'Nom';

  @override
  String get commonExSanteEducation => 'Ex : Santé, Éducation...';

  @override
  String get commonAjouter => 'Ajouter';

  @override
  String get commonSupprimerCetteCouleur => 'Supprimer cette couleur ?';

  @override
  String get commonCetteCouleurSeraRetireeDe =>
      'Cette couleur sera retirée de la palette.';

  @override
  String get commonSupprimer => 'Supprimer';

  @override
  String get commonRrggbb => 'RRGGBB';

  @override
  String commonMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
      zero: '0 membre',
    );
    return '$_temp0';
  }

  @override
  String get groupsInvalidInviteLinkBody =>
      'Ce lien d\'invitation est invalide ou a expiré. Demande un nouveau lien à un membre du groupe.';

  @override
  String get dashboardRegenerateCodeBody =>
      'Un nouveau code sera créé. Les liens et codes déjà partagés cesseront de fonctionner.';

  @override
  String notesMoreItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+ $count autres',
      one: '+ 1 autre',
      zero: '+ 0 autre',
    );
    return '$_temp0';
  }

  @override
  String get expensesPaidByYou => 'Payé par vous';

  @override
  String expensesPaidBy(String name) {
    return 'Payé par $name';
  }

  @override
  String chatPollVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
      zero: '0 votes',
    );
    return '$_temp0';
  }

  @override
  String get chatPollYours => 'Votre sondage';

  @override
  String get chatPollEditedSuffix => ' · modifié';
}
