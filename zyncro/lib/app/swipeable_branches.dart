import 'package:flutter/material.dart';

/// Conteneur des onglets du shell : on passe d'un onglet à l'autre en
/// balayant vers la gauche / la droite, la page suit le doigt.
///
/// Chaque onglet garde son état (défilement, saisie…) comme avec l'ancien
/// `IndexedStack`. Les gestes horizontaux internes (grille du calendrier,
/// onglets Dépenses / Équilibre, glisser pour répondre dans le chat) restent
/// prioritaires : ils sont plus profonds dans l'arbre.
class SwipeableBranches extends StatefulWidget {
  const SwipeableBranches({
    super.key,
    required this.currentIndex,
    required this.onSwipeTo,
    required this.children,
  });

  /// Onglet affiché (source de vérité : le router).
  final int currentIndex;

  /// Appelé quand un balayage amène sur un autre onglet.
  final ValueChanged<int> onSwipeTo;

  /// Navigators des branches, dans l'ordre des onglets.
  final List<Widget> children;

  @override
  State<SwipeableBranches> createState() => _SwipeableBranchesState();
}

class _SwipeableBranchesState extends State<SwipeableBranches> {
  late final PageController _controller;

  /// Dernier onglet connu des deux côtés : évite que le changement venu du
  /// balayage revienne en écho comme un saut de page, et inversement.
  /// Initialisé dans initState (un `late` paresseux serait lu pour la
  /// première fois dans didUpdateWidget, avec le NOUVEL index).
  late int _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.currentIndex;
    _controller = PageController(initialPage: _shown);
  }

  @override
  void didUpdateWidget(SwipeableBranches oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changement venu d'ailleurs (barre d'onglets, notification, lien) :
    // saut direct, comme avant.
    if (widget.currentIndex != _shown) {
      _shown = widget.currentIndex;
      if (_controller.hasClients) _controller.jumpToPage(_shown);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _controller,
      onPageChanged: (index) {
        if (index == _shown) return;
        setState(() => _shown = index);
        widget.onSwipeTo(index);
      },
      children: [
        for (final (index, child) in widget.children.indexed)
          // Onglets hors écran : animations en pause (comme l'ancien
          // IndexedStack), pour la batterie.
          TickerMode(
            enabled: index == _shown,
            child: _KeepAlive(child: child),
          ),
      ],
    );
  }
}

/// Garde l'onglet en mémoire hors écran (état conservé).
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
