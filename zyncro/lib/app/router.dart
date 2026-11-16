import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zyncro/app/app_shell.dart';
import 'package:zyncro/app/redirect_policy.dart';
import 'package:zyncro/app/swipeable_branches.dart';
import 'package:zyncro/core/navigation/app_routes.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/auth/presentation/screens/login_screen.dart';
import 'package:zyncro/features/auth/presentation/screens/profile_screen.dart';
import 'package:zyncro/features/auth/presentation/screens/register_screen.dart';
import 'package:zyncro/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:zyncro/features/calendar/presentation/screens/calendar_settings_screen.dart';
import 'package:zyncro/features/chat/presentation/screens/chat_screen.dart';
import 'package:zyncro/features/chat/presentation/screens/chat_settings_screen.dart';
import 'package:zyncro/features/chat/presentation/screens/media_gallery_screen.dart';
import 'package:zyncro/features/chat/presentation/screens/share_to_group_screen.dart';
import 'package:zyncro/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:zyncro/features/dashboard/presentation/screens/home_settings_screen.dart';
import 'package:zyncro/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:zyncro/features/expenses/presentation/screens/expenses_settings_screen.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/groups/presentation/providers/invite_link_provider.dart';
import 'package:zyncro/features/groups/presentation/screens/group_selection_screen.dart';
import 'package:zyncro/features/groups/presentation/screens/join_by_link_screen.dart';
import 'package:zyncro/features/notes/presentation/screens/notes_screen.dart';
import 'package:zyncro/features/notes/presentation/screens/notes_settings_screen.dart';

final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(),
);

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier<int>(0);
  final navigatorKey = ref.read(rootNavigatorKeyProvider);

  ref.listen(authStateProvider, (_, __) => notifier.value++);
  ref.listen(selectedGroupIdProvider, (_, __) => notifier.value++);
  ref.listen(userGroupsProvider, (_, __) => notifier.value++);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: AppRoutes.login,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);
      final groupIdAsync = ref.read(selectedGroupIdProvider);
      return computeRedirect(
        authLoading: authAsync.isLoading,
        loggedIn: authAsync.asData?.value != null,
        path: state.uri.path,
        pendingInviteCode: ref.read(inviteLinkProvider),
        groupLoading: groupIdAsync.isLoading,
        selectedGroupId: groupIdAsync.asData?.value,
      );
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.groups,
        builder: (_, __) => const GroupSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.invitePattern,
        builder: (_, state) =>
            JoinByLinkScreen(code: state.pathParameters['code']!),
      ),
      GoRoute(
        path: AppRoutes.mediaGallery,
        builder: (_, __) => const MediaGalleryScreen(),
      ),
      GoRoute(
        path: AppRoutes.share,
        builder: (_, __) => const ShareToGroupScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsHome,
        builder: (_, __) => const HomeSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsCalendar,
        builder: (_, __) => const CalendarSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsNotes,
        builder: (_, __) => const NotesSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsExpenses,
        builder: (_, __) => const ExpensesSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsChat,
        builder: (_, __) => const ChatSettingsScreen(),
      ),
      // Onglets : balayage gauche / droite entre onglets (SwipeableBranches),
      // tous préchargés pour qu'un onglet jamais ouvert ne soit pas vide
      // pendant le balayage.
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(shell: shell),
        navigatorContainerBuilder: (context, shell, children) =>
            SwipeableBranches(
              currentIndex: shell.currentIndex,
              onSwipeTo: shell.goBranch,
              children: children,
            ),
        branches: [
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, __) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: AppRoutes.calendar,
                builder: (_, __) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: AppRoutes.notes,
                builder: (_, __) => const NotesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: AppRoutes.expenses,
                builder: (_, __) => const ExpensesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: AppRoutes.chat,
                builder: (_, __) => const ChatScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
