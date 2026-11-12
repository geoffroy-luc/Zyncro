/// Action à effectuer sur un appui du bouton retour Android dans le shell.
enum BackNavigationAction {
  /// Laisser la pile de l'onglet courant dépiler (écran poussé dans l'onglet).
  popBranch,

  /// Revenir à l'onglet Accueil.
  goToHomeTab,

  /// Revenir à la liste des espaces.
  goToGroups,
}

/// Politique du bouton retour (POINT D'EXTENSION, non branché : feature
/// « gestion propre du bouton retour Android », docs/refactor/PLAN.md §3).
///
/// Aujourd'hui le retour depuis la racine d'un onglet ferme l'app
/// (BUGS_FOUND G10). Pour la brancher : `PopScope(canPop: false,
/// onPopInvokedWithResult: …)` dans app_shell.dart, qui appelle cette
/// fonction puis `shell.goBranch(0)` / `context.go(AppRoutes.groups)`.
BackNavigationAction decideBackNavigation({
  required int currentTabIndex,
  required bool branchCanPop,
}) {
  if (branchCanPop) return BackNavigationAction.popBranch;
  if (currentTabIndex != 0) return BackNavigationAction.goToHomeTab;
  return BackNavigationAction.goToGroups;
}
