import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zyncro/core/navigation/app_routes.dart';
import 'package:zyncro/core/theme/app_theme.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/design_system/tokens/brand_palette.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';
import 'package:zyncro/l10n/generated/app_localizations.dart';
// ── Default tab gradients ────────────────────────────────────────────────────

const _defaultTabGradients = TabPalette.gradients;

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
  final base = hexToColor(hex);
  return [base, darken(base)];
}

List<String> _tabTitles(AppLocalizations l10n) => [
  l10n.tabHomeTitle,
  l10n.tabCalendarTitle,
  l10n.tabNotesTitle,
  l10n.tabExpensesTitle,
  l10n.tabChatTitle,
];

List<String> _navLabels(AppLocalizations l10n) => [
  l10n.navHome,
  l10n.navCalendar,
  l10n.navNotes,
  l10n.navExpenses,
  l10n.navChat,
];

// ── App shell ────────────────────────────────────────────────────────────────

/// Durée des transitions de couleur et de titre entre onglets.
const _tabTransition = Duration(milliseconds: 250);

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell shell;

  const AppShell({super.key, required this.shell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StatefulNavigationShell get shell => widget.shell;

  static const _navItems = [
    _NavItem(Icons.home_outlined, Icons.home_rounded),
    _NavItem(Icons.calendar_month_outlined, Icons.calendar_month_rounded),
    _NavItem(Icons.description_outlined, Icons.description_rounded),
    _NavItem(Icons.attach_money, Icons.attach_money),
    _NavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _syncChatTabActive();
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shell.currentIndex != widget.shell.currentIndex) {
      _syncChatTabActive();
    }
  }

  /// Synchronise l'état « chat actif » avec l'onglet courant (gère le cas où
  /// l'app s'ouvre directement sur le chat via une notification).
  void _syncChatTabActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(isChatTabActiveProvider.notifier)
          .setActive(widget.shell.currentIndex == 4);
    });
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(selectedGroupProvider);
    final settings =
        ref.watch(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    final topPad = MediaQuery.of(context).padding.top;
    final idx = shell.currentIndex;
    final gradientColors = _gradientForTab(idx, settings);
    final primaryColor = gradientColors.first;
    final tabTitle = _tabTitles(context.l10n)[idx];
    final navLabels = _navLabels(context.l10n);

    // Photo du groupe — lue depuis le modèle Group (visible partout)
    final groupPhotoUrl = group?.photoUrl;

    // Hauteur totale du top bar : padding haut + contenu (40px) + padding bas
    final topBarHeight = topPad + 76.0;

    // Couleur de l'onglet : fondu entre les couleurs au changement d'onglet
    // (boutons, accents) au lieu d'un basculement net.
    return AnimatedTheme(
      data: AppTheme.themed(primaryColor),
      duration: _tabTransition,
      curve: Curves.easeOut,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: Builder(
          builder: (bodyContext) {
            // `bodyContext` (contrairement au `context` de AppShell, situé
            // au-dessus du Scaffold) est à l'intérieur du body du Scaffold :
            // son MediaQuery a déjà viewInsets.bottom mis à 0 par
            // resizeToAvoidBottomInset quand le clavier est ouvert. Utiliser
            // MediaQuery.of(context) ici écraserait cet ajustement avec les
            // valeurs brutes et empêcherait tout le contenu (dont le chat) de
            // remonter au-dessus du clavier.
            final bodyMediaQuery = MediaQuery.of(bodyContext);
            return Stack(
              children: [
                // Shell remplit toute la hauteur — son fond s'étend dans les coins du top bar
                MediaQuery(
                  data: bodyMediaQuery.copyWith(
                    padding: bodyMediaQuery.padding.copyWith(
                      top: topBarHeight,
                      bottom: 0,
                    ),
                  ),
                  child: shell,
                ),
                // Top bar overlay avec coins arrondis
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: _tabTransition,
                    curve: Curves.easeOut,
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
                            if (context.mounted) context.go(AppRoutes.groups);
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
                              AnimatedSwitcher(
                                duration: _tabTransition,
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [...previous, ?current],
                                ),
                                child: Text(
                                  tabTitle,
                                  key: ValueKey(tabTitle),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Paramètres (onglet-spécifiques)
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.tabSettings[idx]),
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
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: context.colors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                          // Couleur de l'icône et du libellé : fondu.
                          child: TweenAnimationBuilder<Color?>(
                            tween: ColorTween(
                              end: isActive
                                  ? primaryColor
                                  : context.colors.textSecondary,
                            ),
                            duration: _tabTransition,
                            curve: Curves.easeOut,
                            builder: (context, color, _) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isActive ? item.activeIcon : item.icon,
                                  size: 24,
                                  color: color,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  navLabels[i],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;

  const _NavItem(this.icon, this.activeIcon);
}
