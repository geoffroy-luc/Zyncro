import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/app/back_navigation_policy.dart';
import 'package:zyncro/app/redirect_policy.dart';

String? redirect({
  bool authLoading = false,
  bool loggedIn = true,
  required String path,
  String? invite,
  bool groupLoading = false,
  String? groupId = 'g1',
}) => computeRedirect(
  authLoading: authLoading,
  loggedIn: loggedIn,
  path: path,
  pendingInviteCode: invite,
  groupLoading: groupLoading,
  selectedGroupId: groupId,
);

void main() {
  group('computeRedirect', () {
    test('chargement de l\'auth : aucune redirection', () {
      expect(
        redirect(authLoading: true, loggedIn: false, path: '/home'),
        isNull,
      );
    });
    test('déconnecté → /login, sauf inscription', () {
      expect(redirect(loggedIn: false, path: '/home'), '/login');
      expect(redirect(loggedIn: false, path: '/i/ABC234'), '/login');
      expect(redirect(loggedIn: false, path: '/register'), isNull);
      expect(redirect(loggedIn: false, path: '/login'), '/login');
    });
    test(
      'connecté sur login/inscription → invitation en attente ou espaces',
      () {
        expect(redirect(path: '/login'), '/groups');
        expect(redirect(path: '/register'), '/groups');
        expect(redirect(path: '/login', invite: 'ABC234'), '/i/ABC234');
      },
    );
    test('onglet sans espace sélectionné → /groups', () {
      for (final tab in [
        '/home',
        '/calendar',
        '/notes',
        '/expenses',
        '/chat',
      ]) {
        expect(redirect(path: tab, groupId: null), '/groups');
        expect(redirect(path: tab), isNull);
      }
    });
    test('chargement de l\'espace : aucune redirection', () {
      expect(
        redirect(path: '/home', groupId: null, groupLoading: true),
        isNull,
      );
    });
    test('hors espace : pas de redirection même sans espace', () {
      expect(redirect(path: '/groups', groupId: null), isNull);
      expect(redirect(path: '/profile', groupId: null), isNull);
    });

    test(
      'BUG G9 corrigé : réglages d’onglet et galerie sans espace → /groups',
      () {
        expect(redirect(path: '/settings/chat', groupId: null), '/groups');
        expect(redirect(path: '/settings/home', groupId: null), '/groups');
        expect(redirect(path: '/media-gallery', groupId: null), '/groups');
        expect(redirect(path: '/settings/chat'), isNull);
      },
    );
  });

  group('decideBackNavigation (non branché)', () {
    test('pile de l\'onglet non vide → dépiler', () {
      expect(
        decideBackNavigation(currentTabIndex: 3, branchCanPop: true),
        BackNavigationAction.popBranch,
      );
    });
    test('racine d\'un sous-onglet → Accueil, puis espaces', () {
      expect(
        decideBackNavigation(currentTabIndex: 2, branchCanPop: false),
        BackNavigationAction.goToHomeTab,
      );
      expect(
        decideBackNavigation(currentTabIndex: 0, branchCanPop: false),
        BackNavigationAction.goToGroups,
      );
    });
  });
}
