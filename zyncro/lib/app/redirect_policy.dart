import 'package:zyncro/core/navigation/app_routes.dart';

/// Redirection globale du router, sous forme de fonction PURE (testée).
///
/// - pas connecté → login (sauf inscription) ;
/// - connecté sur login/inscription → lien d'invitation en attente, sinon
///   la liste des espaces ;
/// - onglet du shell, réglage d'onglet ou galerie sans espace sélectionné →
///   liste des espaces.
/// `null` = pas de redirection (y compris pendant les chargements).
String? computeRedirect({
  required bool authLoading,
  required bool loggedIn,
  required String path,
  required String? pendingInviteCode,
  required bool groupLoading,
  required String? selectedGroupId,
}) {
  if (authLoading) return null;
  if (!loggedIn) {
    if (path == AppRoutes.register) return null;
    return AppRoutes.login;
  }
  if (path == AppRoutes.login || path == AppRoutes.register) {
    // Un lien d'invitation ouvert hors connexion est rejoué après login.
    if (pendingInviteCode != null) return AppRoutes.invite(pendingInviteCode);
    return AppRoutes.groups;
  }
  if (groupLoading) return null;
  // BUG G9 corrigé : les écrans liés à un espace (onglets, réglages
  // d'onglet, galerie) renvoient à la liste quand il n'y a plus d'espace
  // sélectionné (groupe supprimé, retrait) au lieu d'un spinner infini.
  final groupScoped =
      AppRoutes.shellTabs.contains(path) ||
      AppRoutes.tabSettings.contains(path) ||
      path == AppRoutes.mediaGallery;
  if (groupScoped && selectedGroupId == null) return AppRoutes.groups;
  return null;
}
