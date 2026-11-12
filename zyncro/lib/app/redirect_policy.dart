import 'package:zyncro/core/navigation/app_routes.dart';

/// Redirection globale du router, sous forme de fonction PURE (testée).
///
/// - pas connecté → login (sauf inscription) ;
/// - connecté sur login/inscription → lien d'invitation en attente, sinon
///   la liste des espaces ;
/// - onglet du shell sans espace sélectionné → liste des espaces.
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
  final inShell = AppRoutes.shellTabs.contains(path);
  if (inShell && selectedGroupId == null) return AppRoutes.groups;
  return null;
}
