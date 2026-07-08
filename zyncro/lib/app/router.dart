import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/profile_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/calendar/presentation/screens/calendar_screen.dart';
import '../features/calendar/presentation/screens/calendar_settings_screen.dart';
import '../features/chat/presentation/screens/chat_screen.dart';
import '../features/chat/presentation/screens/chat_settings_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/dashboard/presentation/screens/home_settings_screen.dart';
import '../features/expenses/presentation/screens/expenses_screen.dart';
import '../features/expenses/presentation/screens/expenses_settings_screen.dart';
import '../features/groups/presentation/providers/groups_provider.dart';
import '../features/groups/presentation/providers/tab_settings_provider.dart';
import '../features/groups/presentation/screens/group_selection_screen.dart';
import '../features/groups/presentation/screens/group_settings_screen.dart';
import '../features/notes/presentation/screens/notes_screen.dart';
import '../features/notes/presentation/screens/notes_settings_screen.dart';
import '../core/constants/app_colors.dart';
import '../shared/models/tab_settings.dart';
import '../features/chat/presentation/providers/messages_provider.dart';
import '../features/chat/presentation/screens/media_gallery_screen.dart';

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
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);
      final isLoading = authAsync.isLoading;
      if (isLoading) return null;

      final user = authAsync.asData?.value;
      final isLoggedIn = user != null;
      final path = state.uri.path;

      if (!isLoggedIn) {
        if (path == '/register') return null;
        return '/login';
      }

      if (path == '/login' || path == '/register') {
        return '/groups';
      }

      final groupIdAsync = ref.read(selectedGroupIdProvider);
      if (groupIdAsync.isLoading) return null;
      final groupId = groupIdAsync.asData?.value;
      final inShell =
          path == '/home' ||
          path == '/calendar' ||
          path == '/notes' ||
          path == '/expenses' ||
          path == '/chat';

      if (inShell && groupId == null) return '/groups';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/groups',
        builder: (_, __) => const GroupSelectionScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/group-settings',
        builder: (_, __) => const GroupSettingsScreen(),
      ),
      GoRoute(
        path: '/media-gallery',
        builder: (_, __) => const MediaGalleryScreen(),
      ),
      GoRoute(
        path: '/settings/home',
        builder: (_, __) => const HomeSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/calendar',
        builder: (_, __) => const CalendarSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/notes',
        builder: (_, __) => const NotesSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/expenses',
        builder: (_, __) => const ExpensesSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/chat',
        builder: (_, __) => const ChatSettingsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (_, __) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/notes', builder: (_, __) => const NotesScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/expenses',
                builder: (_, __) => const ExpensesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});

// ── Default tab gradients ────────────────────────────────────────────────────

const _defaultTabGradients = [
  [Color(0xFF9B59B6), Color(0xFF7D3C98)], // Accueil - violet
  [Color(0xFF4F7CFF), Color(0xFF315FEA)], // Calendrier - bleu
  [Color(0xFF2BB8A5), Color(0xFF1A9B88)], // Notes - vert
  [Color(0xFFFFB86B), Color(0xFFF5A855)], // Dépenses - orange
  [Color(0xFFE85D75), Color(0xFFC94060)], // Chat - rose
];

Color _darken(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
}

List<Color> _gradientForTab(int idx, TabSettings settings) {
  final hex = switch (idx) {
    0 => settings.homeThemeColor,
    1 => settings.calendarThemeColor,
    2 => settings.notesThemeColor,
    3 => settings.expensesThemeColor,
    4 => settings.chatThemeColor,
    _ => null,
  };
  if (hex == null) return _defaultTabGradients[idx];
  final base = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  return [base, _darken(base)];
}

const _settingsRoutes = [
  '/settings/home',
  '/settings/calendar',
  '/settings/notes',
  '/settings/expenses',
  '/settings/chat',
];

const _tabTitles = [
  'Accueil',
  'Calendrier',
  'Notes',
  'Dépenses',
  'Chat',
];

// ── App shell ────────────────────────────────────────────────────────────────

class _AppShell extends ConsumerWidget {
  final StatefulNavigationShell shell;

  const _AppShell({required this.shell});

  static const _navItems = [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(
      Icons.calendar_month_outlined,
      Icons.calendar_month_rounded,
      'Calendar',
    ),
    _NavItem(Icons.description_outlined, Icons.description_rounded, 'Notes'),
    _NavItem(Icons.attach_money, Icons.attach_money, 'Expenses'),
    _NavItem(
      Icons.chat_bubble_outline_rounded,
      Icons.chat_bubble_rounded,
      'Chat',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(selectedGroupProvider);
    final settings =
        ref.watch(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    final topPad = MediaQuery.of(context).padding.top;
    final idx = shell.currentIndex;
    final gradientColors = _gradientForTab(idx, settings);
    final tabTitle = _tabTitles[idx];

    // Synchronise l'état "chat actif" avec l'onglet courant (gère le cas
    // où l'app s'ouvre directement sur le chat via une notification).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isChatTabActiveProvider.notifier).setActive(idx == 4);
    });

    // Photo du groupe — lue depuis le modèle Group (visible partout)
    final groupPhotoUrl = group?.photoUrl;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Column(
        children: [
          // ── Top bar gradient ──────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradientColors,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                // Retour vers Mes espaces
                GestureDetector(
                  onTap: () async {
                    await ref
                        .read(selectedGroupIdProvider.notifier)
                        .select(null);
                    if (context.mounted) context.go('/groups');
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Emoji / photo du groupe
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: groupPhotoUrl != null
                      ? ClipOval(
                          child: Image.network(
                            groupPhotoUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Text(
                            group?.emoji?.isNotEmpty == true
                                ? group!.emoji!
                                : (group?.name.isNotEmpty == true
                                    ? group!.name[0].toUpperCase()
                                    : ''),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                // Nom + titre onglet
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        group?.name ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        tabTitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Paramètres (onglet-spécifiques)
                GestureDetector(
                  onTap: () => context.push(_settingsRoutes[idx]),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Nav items ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_navItems.length, (i) {
                    final item = _navItems[i];
                    final isActive = shell.currentIndex == i;
                    return GestureDetector(
                      onTap: () {
                        ref
                            .read(isChatTabActiveProvider.notifier)
                            .setActive(i == 4);
                        shell.goBranch(
                          i,
                          initialLocation: i == shell.currentIndex,
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive ? item.activeIcon : item.icon,
                              size: 24,
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}
